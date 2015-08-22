(def ^:private colors    (require "colors/safe"))
(def ^:private detective (require "detective"))
(def ^:private logging   (require "etude-logging"))
(def ^:private path      (require "path"))
(def ^:private runtime   (require "./runtime"))
(def ^:private tree      (require "./tree"))
(def ^:private vm        (require "vm"))

(defn- updated
  " Emits when an aspect of a notion (source code, compiled code, value)
    has been updated. "
  [notion what]
  (events.emit (str "notion.updated." what) (freeze-notion notion)))

(defn compile-notion-initial
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
  (set! notion.requires (unique (.-strings
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
    (set! context.log (logging/get-logger (str (colors.bold "@") notion.name)))
    (set! context._   {}); (tree.get-notion-tree NOTIONS notion))
    context))

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

(defn- resolve-notion-prefix
  [from to]
  (conj (.join (.slice (from.name.split "/") 0 -1) "/") "/" to))

(defn- detected [node value]
  (set! node.arguments [{ :type "Literal" :value value }])
  true)

(defn- detect-and-parse-deref
  " Hacks detective module to find `_.<notion-name>`
    expressions (as compiled from `./<notion-name>` in wisp). "
  [notion node]
  (log.as :detect-and-parse-deref notion node)
  (set! node.arguments (or node.arguments []))
  (if (and (= node.type "MemberExpression")
           (= node.object.type "Identifier")
           (= node.object.name "_"))
    (loop [step  node.parent
           value (resolve-notion-prefix notion node.property.name)]
      (if (not (and step (= step.type "MemberExpression")))
        (detected node value)
        (let [next-value (conj value "/" step.property.name)
              not-notion   (= -1 (.index-of (keys NOTIONS) next-value))]
          (if not-notion
            (detected node value)
            (recur step.parent next-value)))))
    false))

(defn- find-derefs
  " Returns a list of notions referenced from a notion. "
  [notion]
  (cond
    (= notion.type "Notion")
      (let [detective (require "detective")
            code      notion.compiled.output.code
            results   (detective.find code
                      { :word      ".*"
                        :isRequire (detect-and-parse-deref.bind nil notion) })]
        (unique results.strings))
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
  (log.as :add-dep deps.length from.name to)
  (if (= -1 (deps.index-of to))
    (let [dep (aget NOTIONS to)]
      (if (not dep) (throw (Error.
        (str "No notion " to " (from " from.name ")"))))
      (deps.push to)
      (find-requires reqs dep)
      (map (fn [to] (add-dep deps reqs dep to)) (find-derefs dep)))))

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

;;
;; utilities
;;

(defn unique
  " Filters an array into a set of unique elements. "
  [arr]
  (let [encountered []]
    (arr.filter (fn [item]
      (if (= -1 (encountered.index-of item))
        (do
          (encountered.push item)
          true)
        false)))))
