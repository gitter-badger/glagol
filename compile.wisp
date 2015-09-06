(def ^:private colors    (require "colors/safe"))
(def ^:private detective (require "detective"))
(def ^:private fs        (require "fs"))
(def ^:private logging   (require "etude-logging"))
(def ^:private path      (require "path"))
(def ^:private runtime   (require "./runtime.js"))
(def ^:private tree      (require "./tree.wisp"))
(def ^:private util      (require "./util.wisp"))
(def ^:private vm        (require "vm"))

(def ^:private translate
  (.-translate-identifier-word (require "wisp/backend/escodegen/writer.js")))

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
  " Prepares an execution context with globals used by notions. 

    Can't assoc context because the resulting object is uncontextified,
    so we rely on our good old friend imperative set! to add some
    notion-specific globals to each notion's VM execution context. "
  (let [context (runtime.make-context notion.path)]
    (set! context.process (assoc context.process :cwd
      (fn [] (path.dirname notion.path))))
    (set! context.log  (logging/get-logger (str (colors/bold "@") notion/name)))
    (set! context.self notion)
    (set! context._    (get-notion-tree notion))
    (set! context.__   (aget (get-notion-tree notion) :__))
    context))

(defn- add-notion [cwd i n]
  (Object.define-property cwd (translate i)
    { :configurable true :enumerable true
      :get (fn []
        (if (or (not n.evaluated) n.outdated)
          (evaluate-notion-sync n))
        (n.value)) }))

(defn- add-notion-dir [cwd i n]
  (Object.define-property cwd (translate i)
    { :configurable true :enumerable true
      :get (fn [] (get-notion-tree n)) }))

(defn get-notion-tree
  " From file, . points to parent and .. to grandparent;
    from dir, .. points to parent and . to self. "
  [notion]
  (let [cwd {}]
    (cond
      (and (= notion.type "Notion") notion.parent)
        (set! cwd (get-notion-tree notion.parent))
      (= notion.type "NotionDirectory") (do
        (set! cwd._  cwd)
        (.map (keys notion.notions) (fn [i]
          (let [n (aget notion.notions i)]
            (cond
              (= n.type "Notion") (add-notion cwd i n)
              (= n.type "NotionDirectory") (add-notion-dir cwd i n)))))
        (if notion.parent (set! cwd.__ (get-notion-tree notion.parent)))))
    cwd))

(defn evaluate-notion-sync
  " Evaluates the notion in a newly created context. "
  [notion]
  ; if the notion's value is up to date, there's nothing to do
  (if (and notion.evaluated (not notion.outdated))
    notion
    (do
      ; if notion has been marked as outdated, reload it from disk
      ; TODO make the file read async, move it to evaluate-notion,
      ; and use that in bin/etude -- or implement a more automated
      ; system altogether, attach watchers to notions, and involve
      ; load-notion and the whole promise-based zoological garden.
      (if notion.outdated (do
        (notion.source.set (fs.read-file-sync notion.path "utf-8"))
        (set! notion.outdated false)
        (set! notion.compiled false)))

      ; compile notion code if not compiled yet
      (if (not notion.compiled) (compile-notion-sync notion))

      ; prepare an execution context for the notion
      (let [context (make-notion-context notion)]

        ; add browserify require to context
        (if process.browser (set! context.require require))

        ; clean up previous instance if possible, and evaluate updated code
        (let [old-value (notion.value)]
          (if (and old-value old-value.destroy) (old-value.destroy)))

        ; prepare source map support
        (vm.run-in-context
          (str "require('"
            (path.resolve (path.join __dirname "node_modules" "source-map-support"))
            "').install()") context)

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

