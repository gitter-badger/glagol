(def ^:private Q (require "q"))
(set! Q.longStackSupport true)

(def ^:private colors    (require "colors/safe"))
(def ^:private detective (require "detective"))
(def ^:private fs        (require "fs"))
(def ^:private glob      (require "glob"))
(def ^:private logging   (require "etude-logging"))
(def ^:private observ    (require "observ"))
(def ^:private path      (require "path"))
(def ^:private resolve   (require "resolve"))
(def ^:private runtime   (require "./runtime.js"))
(def ^:private tree      (require "./tree.wisp"))
(def ^:private url       (require "url"))
(def ^:private vm        (require "vm"))

(def ^:private = runtime.wisp.runtime.is-equal)

(def translate
  (.-translate-identifier-word (require "wisp/backend/escodegen/writer.js")))

;;
;; global state
;;

(def root-dir nil)
(defn get-root-dir [] root-dir)
(def NOTIONS {})

(def log (logging.get-logger "engine"))
(def events (new (.-EventEmitter2 (require "eventemitter2"))
  { :maxListeners 32
    :wildcard     true }))

;;
;; server-side file watcher
;;

(def watcher { :add (fn []) :on (fn []) })
(if (not process.browser)
  (let [chokidar (require "chokidar")]
    (set! watcher (chokidar.watch "" { :persistent true :alwaysStat true }))))

;;
;; ignition
;;

(defn start
  " Starts up the engine in a specified root directory. "
  [dir]
  (log "starting etude engine in" (colors.green dir))
  (set! root-dir dir)
  (load-notion-directory dir))

;;
;; loading and reloading
;;

;(log (colors.gray "█") (colors.blue (path.basename dir)))
;(log (colors.gray (if (= i (- files.length 1)) "└──" "├──"))
;(colors.green (path.basename filename)))

(defn- ignore-files
  [files]
  (files.filter (fn [filename] (= -1 (filename.index-of "node_modules")))))

(defn- updated
  " Emits when an aspect of a notion (source code, compiled code, value)
    has been updated. "
  [notion what]
  (events.emit (str "notion.updated." what) (freeze-notion notion)))

(defn load-notion-directory
  [dir]
  (Q.Promise (fn [resolve reject]
    (glob (path.join dir "*") {} (fn [err files]
      (set! files (ignore-files files))
      (if err (reject err))
      (resolve (Q.allSettled (files.map load-notion))))))))

(defn load-notion
  " Loads a notion from the specified path, and adds it to the watcher. "
  [notion-path i arr]
  (Q.Promise (fn [resolve reject]
    (let [rel-path (path.relative root-dir notion-path)]
      (fs.read-file notion-path "utf-8" (fn [err src]
        (if err
          (if (= err.code "EISDIR")
            (resolve (load-notion-directory notion-path))
            (do (log err) (reject err)))
          (let [notion (make-notion rel-path src)]
            (updated notion :value)
            (watcher.add notion-path)
            (install-notion resolve notion)))))))))

(defn install-notion [resolve notion]
  (loop [notion-path   notion.name
         current-dir NOTIONS]
    (if (= -1 (notion-path.index-of "/"))
      (do
        (tree.add-notion evaluate-notion current-dir notion-path notion)
        (resolve notion))
      (let [child-dir (-> notion-path (.split "/") (aget 0))]
        (if (not (aget current-dir child-dir)) (aset current-dir child-dir {}))
        (recur (tree.descend-path notion-path) (aget current-dir child-dir))))))

(defn reload-notion
  " Reloads a notion's source code from a file.
    TODO: pass notion instead of path? "
  [notion-path file-stat]
  (fs.read-file notion-path "utf-8" (fn [err src]
    (if err (do (log err) (throw err)))
    (let [rel-path  (path.relative root-dir notion-path)
          notion-name (translate rel-path)
          notion      (aget NOTIONS notion-name)]
      (if (not (= src (notion.source))) (notion.source.set src))))))

(watcher.on "change" reload-notion)
;(runtime.compile-source (notion.source) notion.name)

;;
;; constructors
;;

(defn make-notion
  " Creates a new notion, optionally with a preloaded source. "
  [notion-path source]
  (let [notion
          { :type      "Notion"
            :path      (path.resolve root-dir notion-path)
            :name      notion-path
            :source    (observ (.trim (or source "")))
            :compiled  nil
            :requires  []
            :value     (observ undefined)
            :evaluated false
            :outdated  false }]

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
            (evaluate-notion-sync notion))))))))

    ; emit event on value update
    (notion.value (updated.bind nil notion :value))

    notion))

(defn make-notion-directory
  [notion-path]
  { :type "NotionDirectory"
    :name notion-path
    :path (path.resolve root-dir notion-path) })

;;
;; compilation and evaluation
;;

(defn compile-notion-sync
  " Compiles a notion's source code and determines its dependencies. "
  [notion]
  (set! notion.compiled (runtime.compile-source (notion.source) notion.name))
  (set! notion.requires (unique (.-strings
    (detective.find notion.compiled.output.code))))
  notion)

(defn- descend-tree [tree path]
  (loop [current-node   tree
         path-fragments (path.split "/")]

    ; error checking; TODO throw when trying to descend down a file
    (if (> path-fragments.length 0)
      (do
        (if (= -1 (.index-of (keys current-node) (aget path-fragments 0)))
          (throw (Error. (str "No notion at path " path))))
        (recur
          (aget current-node (aget path-fragments 0))
          (path-fragments.slice 1)))
      current-node)))

(defn run-notion
  " Promises to evaluate a notion, if it exists. "
  [notion-path]
  (Q.Promise (fn [resolve reject]
    (resolve (evaluate-notion (descend-tree NOTIONS notion-path))))))

(defn evaluate-notion
  " Promises to evaluate a notion. "
  [notion]
  (Q.Promise (fn [resolve reject]
    (try (resolve (evaluate-notion-sync notion))
      (catch e (reject e))))))

(defn make-notion-context [notion]
  " Prepares an execution context with globals used by notions. "
  (let [context-name (path.resolve root-dir notion.name)
        context      (runtime.make-context context-name)]
    ; can't use assoc because the resulting object is uncontextified
    (set! context.log (logging/get-logger (str (colors.bold "@") notion.name)))
    (set! context._   (tree.get-notion-tree NOTIONS notion))
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
;; freezing notions for serialization
;;

(defn freeze-notions
  " Returns a static snapshot of all loaded notions. "
  []
  (let [snapshot {}]
    (.map (keys NOTIONS) (fn [i]
      (let [frozen (freeze-notion (aget NOTIONS i))]
        (aset snapshot i frozen))))
    snapshot))

(defn freeze-notion
  " Returns a static snapshot of a single notion. "
  [notion]
  (cond
    (= notion.type "Notion")
      (let [frozen
              { :name     notion.name
                :type     "Notion"
                :path     (path.relative root-dir notion.path)
                :source   (notion.source)
                :compiled notion.compiled.output.code }]
        (if notion.evaluated (set! frozen.value (notion.value)))
        (set! frozen.timestamp (Math.floor (Date.now)))
        frozen)
    (= notion.type "NotionDirectory")
      { :name      notion.name
        :type      "NotionDirectory"
        :path      (path.relative root-dir notion.path)
        :timestamp (Math.floor (Date.now)) }))

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
