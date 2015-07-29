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
;; project-level operations
;;

(defn start
  " Starts up the engine in a specified root directory. "
  [dir]
  (set! root-dir dir)
  (.then (list-atoms dir) (fn [atom-paths]
    (let [names (.join (atom-paths.map (path.relative.bind nil dir)) " ")]
      (log "loading atoms" (colors.bold names) "from" (colors.green dir)))
    (Q.allSettled (atom-paths.map load-atom)))))

(defn list-atoms
  " Promises a list of atoms in a specified directory. "
  [dir]
  (Q.Promise (fn [resolve reject]
    (glob (path.join dir "**" "*") {} (fn [err atoms]
      (set! atoms (atoms.filter (fn [a] (= -1 (a.index-of "node_modules")))))
      (if err (do (log err) (reject err)))
      (resolve atoms))))))

;;
;; atom-level operations
;;

(defn- updated
  " Emits when an aspect of an atom (source code, compiled code, value)
    has been updated. "
  [atom what]
  (events.emit (str "atom.updated." what) (freeze-atom atom)))

(defn load-atom
  " Loads an atom from the specified path, and adds it to the watcher. "
  [atom-path]
  (Q.Promise (fn [resolve reject]
    (fs.read-file atom-path "utf-8" (fn [err src]
      (if err (do (log err) (reject err)))
      (let [rel-path (path.relative root-dir atom-path)
            atom     (make-atom rel-path src)]
        (set! (aget ATOMS (translate rel-path)) atom)
        (updated atom :value)
        (watcher.add atom-path)
        (resolve atom)))))))

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
            :derefs    []
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

    ; listen for value updates from dependencies
    ;(events.on "atom.updated.value" (fn [frozen-atom]
      ;(if (not (= -1 (.index-of atom.derefs frozen-atom.name)))
        ;(log "dependency of" atom.name "updated:" frozen-atom.name))))

    atom))

(defn compile-atom-sync
  " Compiles an atom's source code and determines its dependencies. "
  [atom]
  (set! atom.compiled (runtime.compile-source (atom.source) atom.name))
  (let [code atom.compiled.output.code]
    (set! atom.requires
      (unique (.-strings     (detective.find code))))
    (set! atom.derefs
      (unique (.-expressions (detective.find code { :word "deref" })))))
  atom)

(defn freeze-atoms
  " Returns a static snapshot of all loaded atoms. "
  []
  (let [snapshot {}]
    (.map (Object.keys ATOMS) (fn [i]
      (let [frozen (freeze-atom (aget ATOMS i))]
        (set! (aget snapshot i) frozen))))
    snapshot))

(defn freeze-atom
  " Returns a static snapshot of a single atom. "
  [atom]
  (let [frozen
          { :name     atom.name
            :path     (path.relative root-dir atom.path)
            :source   (atom.source)
            :compiled atom.compiled.output.code
            :derefs   atom.derefs }]
    (if atom.evaluated (set! frozen.value (atom.value)))
    (set! frozen.timestamp (Math.floor (Date.now)))
    frozen))

(defn run-atom
  " Promises to evaluate an atom, if it exists. "
  [name]
  (Q.Promise (fn [resolve reject]
    (if (= -1 (.index-of (Object.keys ATOMS) name))
      (reject (str "No atom " name)))
    (resolve (evaluate-atom (aget ATOMS name))))))

(defn evaluate-atom
  " Promises to evaluate an atom. "
  [atom]
  (Q.Promise (fn [resolve reject]
    (try (resolve (evaluate-atom-sync atom))
      (catch e (reject e))))))

(defn make-dereferencer
  " Returns a new atom dereferencer that keeps track of what atoms
    have actually been dereferenced at runtime. "
  []
  (let [deref-deps
          []
        dereferencer
          (fn dereferencer [atom]
            (if (string? atom) (dereferencer (aget ATOMS atom))
              (do
                (if (= -1 (deref-deps.index-of atom.name))
                  (deref-deps.push atom.name))
                (if (and atom.evaluated (not atom.outdated))
                  (.value atom))
                  (.value (evaluate-atom-sync atom)))))]
    (set! dereferencer.deps deref-deps)
    dereferencer))

(defn evaluate-atom-sync
  " Evaluates the atom in a newly created context. "
  [atom]

  ; if the atom's value is up to date, there's nothing to do
  (if (and atom.evaluated (not atom.outdated))
    atom
    (do

      ; compile atom code if not compiled yet
      (if (not atom.compiled) (compile-atom-sync atom))
      (let [code    atom.compiled.output.code
            context (runtime.make-context (path.resolve root-dir atom.name))]

        ; add a nicer logger
        (set! context.log
          (logging.get-logger (str (colors.bold "@") atom.name)))

        ; make loaded atoms available in context; add atom dereferencer
        (.map (Object.keys ATOMS) (fn [i]
          (let [atom (aget ATOMS i)]
            (set! (aget context (translate atom.name)) atom))))
        (set! context.deref (make-dereferencer))

        ; add browserify require to context
        (if process.browser (set! context.require require))

        ; clean up previous instance if possible, and evaluate updated code
        (let [old-value (atom.value)]
          (if (and old-value old-value.destroy) (old-value.destroy)))

        (let [value (vm.run-in-context (runtime.wrap code) context
                      { :filename atom.name })]

          ; if a runtime error has arisen, throw it upwards
          (if context.error
            (throw context.error)

            ; otherwise store the updated value and return the atom
            (do
              (set! atom.evaluated true)
              (atom.value.set value)
              atom)))))))

(defn get-deps
  " Returns a processed list of the dependencies of an atom; used by etude-web "
  [atom]
  (let [derefs
          []
        requires
          []
        find-requires
          (fn [atom]
            (atom.requires.map (fn [req]
              (let [resolved (resolve.sync req { :basedir    root-dir
                                                 :extensions [".js" ".wisp"] })]
                (if (= -1 (requires.index-of resolved)) (do
                  (requires.push resolved)))))))
        add-dep
          nil
        _
          (set! add-dep (fn add-dep [atom-name]
            (if (= -1 (derefs.index-of atom-name))
              (let [dep (aget ATOMS atom-name)]
                (if (not dep) (throw (Error. (str "No atom " atom-name))))
                (derefs.push atom-name)
                (find-requires dep)
                (dep.derefs.map add-dep))))) ]
    (find-requires atom)
    (atom.derefs.map add-dep)
    { :derefs   derefs
      :requires requires }))

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
