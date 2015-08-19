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
(def ATOMS {})

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
  (load-atom-directory dir))

;;
;; loading and reloading
;;

(defn load-atom-directory
  [dir]
  (Q.Promise (fn [resolve reject]
    (glob (path.join dir "*") {} (fn [err files]
      (set! files (ignore-files files))
      (if err (reject err))
      (do
        (log (colors.gray "█") (colors.blue (path.basename dir)))
        (resolve (Q.allSettled (files.map (fn [filename i]
          (log (colors.gray (if (= i (- files.length 1)) "└──" "├──"))
               (colors.green (path.basename filename)))
          (load-atom filename)))))))))))

(defn- ignore-files
  [files]
  (files.filter (fn [filename] (= -1 (filename.index-of "node_modules")))))

(defn load-atom
  " Loads an atom from the specified path, and adds it to the watcher. "
  [atom-path i arr]
  ;(log.as :load-atom atom-path)
  (Q.Promise (fn [resolve reject]
    (let [rel-path (path.relative root-dir atom-path)]
      (fs.read-file atom-path "utf-8" (fn [err src]
        (if err
          (if (= err.code "EISDIR")
            (do ;
                (load-atom-directory atom-path))
            (do (log err)
                (reject err)))
          (let [atom (make-atom rel-path src)]
            (updated atom :value)
            (watcher.add atom-path)
            (install-atom resolve atom)))))))))

(defn- updated
  " Emits when an aspect of an atom (source code, compiled code, value)
    has been updated. "
  [atom what]
  (events.emit (str "atom.updated." what) (freeze-atom atom)))

(defn- install-atom [resolve atom]
  (let [rel-path (path.relative root-dir atom.path)
        atom-key (rel-path.replace (RegExp. "\\." "g") "/")]
    (aset ATOMS atom-key atom)
    (resolve atom)))

(defn reload-atom
  " Reloads an atom's source code from a file.
    TODO: pass atom instead of path? "
  [atom-path file-stat]
  (fs.read-file atom-path "utf-8" (fn [err src]
    (if err (do (log err) (throw err)))
    (let [rel-path  (path.relative root-dir atom-path)
          atom-name (translate rel-path)
          atom      (aget ATOMS atom-name)]
      (if (not (= src (atom.source))) (atom.source.set src))))))

(watcher.on "change" reload-atom)
;(runtime.compile-source (atom.source) atom.name)

;;
;; constructors
;;

(defn make-atom
  " Creates a new atom, optionally with a preloaded source. "
  [atom-path source]
  (let [atom
          { :type      "Atom"
            :path      (path.resolve root-dir atom-path)
            :name      atom-path
            :source    (observ (.trim (or source "")))
            :compiled  nil
            :requires  []
            :value     (observ undefined)
            :evaluated false
            :outdated  false }]

    ; compile source now and on update
    (compile-atom-sync atom)
    (atom.source (fn []
      (updated atom :source)
      (let [old-compiled (if atom.compiled atom.compiled.output.code nil)]
        (compile-atom-sync atom)
        (if (not (= old-compiled atom.compiled.output.code)) (do
          (updated atom :compiled)
          (if atom.evaluated (do
            (set! atom.outdated true)
            (evaluate-atom-sync atom))))))))

    ; emit event on value update
    (atom.value (updated.bind nil atom :value))

    atom))

(defn make-atom-directory
  [atom-path]
  { :type "AtomDirectory"
    :name atom-path
    :path (path.resolve root-dir atom-path) })

;;
;; compilation and evaluation
;;

(defn compile-atom-sync
  " Compiles an atom's source code and determines its dependencies. "
  [atom]
  (set! atom.compiled (runtime.compile-source (atom.source) atom.name))
  (set! atom.requires (unique (.-strings
    (detective.find atom.compiled.output.code))))
  atom)

(defn run-atom
  " Promises to evaluate an atom, if it exists. "
  [name]
  (Q.Promise (fn [resolve reject]
    (if (= -1 (.index-of (keys ATOMS) name))
      (reject (str "No atom " name)))
    (resolve (evaluate-atom (aget ATOMS name))))))

(defn evaluate-atom
  " Promises to evaluate an atom. "
  [atom]
  (Q.Promise (fn [resolve reject]
    (try (resolve (evaluate-atom-sync atom))
      (catch e (reject e))))))

(defn make-atom-context [atom]
  " Prepares an execution context with globals used by atoms. "
  (let [context-name (path.resolve root-dir atom.name)
        context      (runtime.make-context context-name)]
    ; can't use assoc because the resulting object is uncontextified
    (set! context.log (logging/get-logger (str (colors.bold "@") atom.name)))
    (set! context._   (get-atom-tree atom))
    context))

(defn get-atom-tree [start-atom]
  (let [tree {}]
    (.map (keys ATOMS) (fn [atom-name]
      (let [atom (aget ATOMS atom-name)]
        (Object.define-property tree (translate atom.name)
          { :configurable true
            :enumerable   true
            :get (fn []  (if (not atom.evaluated) (evaluate-atom atom))
                         (atom.value))
            :set (fn [v] (atom.value.set v)) }))))
    tree))

(defn evaluate-atom-sync
  " Evaluates the atom in a newly created context. "
  [atom]

  ; if the atom's value is up to date, there's nothing to do
  (if (and atom.evaluated (not atom.outdated))
    atom
    (do
      ; compile atom code if not compiled yet
      (if (not atom.compiled) (compile-atom-sync atom))

      ; prepare an execution context for the atom
      (let [context (make-atom-context atom)]

        ; add browserify require to context
        (if process.browser (set! context.require require))

        ; clean up previous instance if possible, and evaluate updated code
        (let [old-value (atom.value)]
          (if (and old-value old-value.destroy) (old-value.destroy)))

        ; execute the atom code
        (let [value (vm.run-in-context
                      (runtime.wrap atom.compiled.output.code)
                      context { :filename atom.name })]

          ; if a runtime error has arisen, throw it upwards
          (if context.error
            (throw context.error)

            ; otherwise store the updated value and return the atom
            (do
              (set! atom.evaluated true)
              (atom.value.set value)
              atom)))))))

;;
;; freezing atoms for serialization
;;

(defn freeze-atoms
  " Returns a static snapshot of all loaded atoms. "
  []
  (let [snapshot {}]
    (.map (keys ATOMS) (fn [i]
      (let [frozen (freeze-atom (aget ATOMS i))]
        (aset snapshot i frozen))))
    snapshot))

(defn freeze-atom
  " Returns a static snapshot of a single atom. "
  [atom]
  (cond
    (= atom.type "Atom")
      (let [frozen
              { :name     atom.name
                :type     "Atom"
                :path     (path.relative root-dir atom.path)
                :source   (atom.source)
                :compiled atom.compiled.output.code }]
        (if atom.evaluated (set! frozen.value (atom.value)))
        (set! frozen.timestamp (Math.floor (Date.now)))
        frozen)
    (= atom.type "AtomDirectory")
      { :name      atom.name
        :type      "AtomDirectory"
        :path      (path.relative root-dir atom.path)
        :timestamp (Math.floor (Date.now)) }))

;;
;; atom interdependency management
;;

(defn- resolve-atom-prefix
  [from to]
  (conj (.join (.slice (from.name.split "/") 0 -1) "/") "/" to))

(defn- detected [node value]
  (set! node.arguments [{ :type "Literal" :value value }])
  true)

(defn- detect-and-parse-deref
  " Hacks detective module to find `_.<atom-name>`
    expressions (as compiled from `./<atom-name>` in wisp). "
  [atom node]
  (set! node.arguments (or node.arguments []))
  (if (and (= node.type "MemberExpression")
           (= node.object.type "Identifier")
           (= node.object.name "_"))
    (loop [step  node.parent
           value (resolve-atom-prefix atom node.property.name)]
      (if (not (and step (= step.type "MemberExpression")))
        (detected node value)
        (let [next-value (conj value "/" step.property.name)
              not-atom   (= -1 (.index-of (keys ATOMS) next-value))]
          (if not-atom
            (detected node value)
            (recur step.parent next-value)))))
    false))

(defn- find-derefs
  " Returns a list of atoms referenced from an atom. "
  [atom]
  (cond
    (= atom.type "Atom")
      (let [detective (require "detective")
            code      atom.compiled.output.code
            results   (detective.find code
                      { :word      ".*"
                        :isRequire (detect-and-parse-deref.bind nil atom) })]
        (unique results.strings))
    (= atom.type "AtomDirectory")
      []))

(defn- find-requires
  [requires atom]
  (cond
    (= atom.type "Atom")
      (atom.requires.map (fn [req]
        (let [resolved
                (.sync (require "resolve") req
                  { :basedir    (path.dirname atom.path)
                    :extensions [".js" ".wisp"] })]
          (if (= -1 (requires.index-of resolved))
            (requires.push resolved)))))
    (= atom.type "AtomDirectory")
      []))

(defn- add-dep
  [deps reqs from to]
  (log.as :add-dep deps.length from.name to)
  (if (= -1 (deps.index-of to))
    (let [dep (aget ATOMS to)]
      (if (not dep) (throw (Error.
        (str "No atom " to " (from " from.name ")"))))
      (deps.push to)
      (find-requires reqs dep)
      (map (fn [to] (add-dep deps reqs dep to)) (find-derefs dep)))))

(defn get-deps
  " Returns a processed list of the dependencies of an atom. "
  [atom]
  (log.as :get-deps atom.path)
  (let [reqs []  ;; native library requires
        deps []] ;; atom dependencies a.k.a. derefs
    (find-requires reqs atom)
    (.map (find-derefs atom)
      (fn [atom-name] (add-dep deps reqs atom atom-name)))
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
