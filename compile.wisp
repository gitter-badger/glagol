(def ^:private colors    (require "colors/safe"))
(def ^:private detective (require "detective"))
(def ^:private logging   (require "etude-logging"))
(def ^:private path      (require "path"))
(def ^:private runtime   (require "./runtime.js"))
(def ^:private tree      (require "./tree.wisp"))
(def ^:private util      (require "./util.wisp"))
(def ^:private vm        (require "vm"))

(defn- updated
  " Emits when an aspect of a notion (source code, compiled code, value)
    has been updated. "
  [notion what]
  (events.emit (str "notion.updated." what) (freeze-notion notion)))

(defn autocompile-on
  " Called by engine after initial load of each notion. "
  []
    ; compile source now and on update
    (compile-notion-sync notion)
    (notion.source (fn []
      (updated notion :source)
      (let [old-compiled (if notion.compiled notion.compiled.output.code nil)]
        (compile-notion-sync notion)
        (if (not (= old-compiled notion.compiled.output.code)) (do
          (updated notion :compiled)
          (if notion.evaluated (do
            (set! notion.outdated true)
            (evaluate-notion-sync notion)))))))))

(defn compile-notion-sync
  " Compiles a notion's source code and determines its dependencies. "
  [notion]
  (set! notion.compiled (runtime.compile-source (notion.source) notion.name))
  (set! notion.requires (util.unique (.-strings
    (detective.find notion.compiled.output.code))))
  notion)

(defn evaluate-notion
  " Promises to evaluate a notion. "
  [notion]
  (Q.Promise (fn [resolve reject]
    (try (resolve (evaluate-notion-sync notion))
      (catch e (reject e))))))

(defn make-notion-context [notion]
  " Prepares an execution context with globals used by notions. "
  (let [context (runtime.make-context notion.path)]
    ; can't use assoc because the resulting object is uncontextified
    (set! context.log  (logging/get-logger (str (colors.bold "@") notion.name)))
    (set! context.self notion)
    (set! context._    (get-notion-tree notion))
    context))

(defn get-notion-tree [notion]
  (loop [
    current
      (cond (= notion.type "NotionDirectory") notion
            (= notion.type "Notion") notion.parent)
    notion-tree
      {}
  ] (.map (keys current.notions) (fn [n]
      ; ignoring notion installed by previous iteration
      (if (= -1 (.index-of (keys notion-tree) n))
        (let [notion (aget current.notions n)]
          (cond
            (= notion.type "NotionDirectory")
              (aset notion-tree n (get-notion-tree notion))
            (= notion.type "Notion")
              (Object.define-property notion-tree n
                { :configurable true
                  :enumerable   true
                  :get
                    (fn []
                      (if (or (not notion.evaluated) notion.outdated)
                        (evaluate-notion-sync notion))
                      (notion.value)) }))))))
    (if current.parent
      (recur current.parent (assoc {} current.name notion-tree))
      notion-tree)))

(defn evaluate-notion-sync
  " Evaluates the notion in a newly created context. "
  [notion]

  ; if the notion's value is up to date, there's nothing to do
  (if (and notion.evaluated (not notion.outdated))
    notion
    (do
      ; compile notion code if not compiled yet
      (if (not notion.compiled) (compile-notion-sync notion))

      ; prepare an execution context for the notion
      (let [context (make-notion-context notion)]

        ; add browserify require to context
        (if process.browser (set! context.require require))

        ; clean up previous instance if possible, and evaluate updated code
        (let [old-value (notion.value)]
          (if (and old-value old-value.destroy) (old-value.destroy)))

        ; execute the notion code
        (let [value (vm.run-in-context
                      (runtime.wrap notion.compiled.output.code)
                      context { :filename notion.name })]

          ; if a runtime error has arisen, throw it upwards
          (if context.error
            (throw context.error)

            ; otherwise store the updated value and return the notion
            (do
              (set! notion.evaluated true)
              (notion.value.set value)
              notion)))))))

;;
;; notion interdependency management
;;

(defn- step? [node]
  (and
    (= node.type "MemberExpression")
    (= node.object.type "Identifier")
    (or (= node.object.name "_") (= node.object.name "__"))))

(defn- get-next-notion [node notion path]
  (if (and node.parent (= node.parent.type "MemberExpression"))
    (let [next-notion (tree.get-notion-by-path notion path)]
      (or next-notion false))))

(defn- detected!
  [node value]
  ; replacing the node with a literal in detective's copy of the ast
  ; allows detective to fish out the end value by itself afterwards
  (set! node.arguments [{ :type "Literal" :value value }])
  true)

(defn- detect-and-parse-deref
  " Hacks detective module to find `_.<notion-name>`
    expressions (as compiled from `./<notion-name>` in wisp). "
  [notion node]
  (set! node.arguments (or node.arguments []))
  (if (step? node)
    (loop [step node
           path (if (= node.object.name "_") "." "..")]
      (let [next-path (conj path "/" step.property.name)]
        (log next-path)
        (let [next-notion (get-next-notion step notion next-path)]
          (if next-notion (recur step.parent next-path)
                          (detected! node next-path)))))
    false))

(defn- find-derefs
  " Returns a list of notions referenced from a notion. "
  [notion]
  (cond
    (= notion.type "Notion")
      (let [detective (require "detective")
            compiled  (or notion.compiled
                        (.-compiled (compile-notion-sync notion)))
            code      compiled.output.code
            results   (detective.find code
                      { :word      ".*"
                        :isRequire (detect-and-parse-deref.bind nil notion) })]
        (log.as :derefs-of notion.name (util.unique results.strings))
        (util.unique results.strings))
    (= notion.type "NotionDirectory")
      []))

(defn- find-requires
  [requires notion]
  (cond
    (= notion.type "Notion")
      (notion.requires.map (fn [req]
        (let [resolved
                (.sync (require "resolve") req
                  { :basedir    (path.dirname notion.path)
                    :extensions [".js" ".wisp"] })]
          (if (= -1 (requires.index-of resolved))
            (requires.push resolved)))))
    (= notion.type "NotionDirectory")
      []))

(defn- add-dep
  [deps reqs from to]
  (let [full-from (tree.get-path from)
        full-to   (path.resolve full-from to)]
    (log.as :add-dep full-from full-to)
    (if (= -1 (deps.index-of full-to))
      (let [dep (tree.get-notion-by-path from to)]
        (if (not dep) (throw (Error.
          (str "No notion " to " (from " from.name ")"))))
        (deps.push full-to)
        (find-requires reqs dep)
        (map (fn [to] (add-dep deps reqs dep to)) (find-derefs dep))))))

(defn get-deps
  " Returns a processed list of the dependencies of a notion. "
  [notion]
  (log.as :get-deps notion.path)
  (let [reqs []  ;; native library requires
        deps []] ;; notion dependencies a.k.a. derefs
    (find-requires reqs notion)
    (.map (find-derefs notion)
      (fn [notion-name] (add-dep deps reqs notion notion-name)))
    { :derefs   deps
      :requires reqs }))

