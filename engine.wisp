(def ^:private Q (require "q"))
(set! Q.longStackSupport true)

(def ^:private colors    (require "colors/safe"))
;(def ^:private chokidar (require "chokidar"))
(def ^:private detective (require "detective"))
(def ^:private fs        (require "fs"))
(def ^:private glob      (require "glob"))
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
;; global singleton state
;;

(def log      (.get-logger (require "etude-logging") "engine"))
(def events   (new (.-EventEmitter2 (require "eventemitter2")) { :maxListeners 32 }))
;(def watcher  (chokidar.watch "" { :persistent true :alwaysStat true}))
(def root-dir nil)
(def ATOMS    {})

;;
;; project-level operations
;;

(defn start [dir]
  (set! root-dir dir)
  (.then (list-atoms dir) (fn [atom-paths] (Q.allSettled (atom-paths.map load-atom)))))

(defn list-atoms [dir]
  (Q.Promise (fn [resolve reject]
    (glob (path.join dir "**" "*") {} (fn [err atoms]
      (set! atoms (atoms.filter (fn [a] (= -1 (a.index-of "node_modules")))))
      (if err (do (log err) (reject err)))
      (let [names (.join (atoms.map (path.relative.bind nil dir)) " ")]
        (log "loading atoms" (colors.bold names) "from" (colors.green dir))
        (resolve atoms)))))))

;;
;; atom-level operations
;;

(defn load-atom [atom-path]
  (Q.Promise (fn [resolve reject]
    (fs.read-file atom-path "utf-8" (fn [err src]
      (if err (do (log err) (reject err)))
      (let [rel-path (path.relative root-dir atom-path)
            atom     (make-atom rel-path src)]
        (set! (aget ATOMS (translate rel-path)) atom)
        (events.emit "atom-updated" (freeze-atom atom))
        (resolve atom)))))))

(defn make-atom [atom-path source]
  (let [atom
          { :type      "Atom"
            :path      atom-path
            :name      atom-path
            :source    (observ (.trim (or source "")))
            :compiled  nil
            :requires  []
            :derefs    []
            :value     (observ undefined)
            :evaluated false
            :outdated  false } ]

    ; compile source now and on update
    (compile-atom-sync atom)
    (atom.source (fn []
      (compile-atom-sync atom)
      (if atom.evaluated (do
        (set! atom.outdated true)
        (evaluate-atom-sync atom)))))

    ; emit event on value update
    (atom.value (fn [] (events.emit "atom-updated" (freeze-atom atom))))

    ; listen for value updates from dependencies
    (events.on "atom-updated" (fn [frozen-atom]
      (if (not (= -1 (.index-of atom.derefs frozen-atom.name)))
        (log "dependency of" atom.name "updated:" frozen-atom.name))))

    atom))

(defn compile-atom-sync [atom]
  (set! atom.compiled (runtime.compile-source (atom.source) atom.name))
  (let [code atom.compiled.output.code]
    (set! atom.requires (unique (.-strings     (detective.find code))))
    (set! atom.derefs   (unique (.-expressions (detective.find code { :word "deref" })))))
  atom)

(defn freeze-atoms []
  (let [snapshot {}]
    (.map (Object.keys ATOMS) (fn [i]
      (let [frozen (freeze-atom (aget ATOMS i))]
        (set! (aget snapshot i) frozen))))
    snapshot))

(defn freeze-atom [atom]
  (let [frozen
          { :path     atom.path
            :name     atom.name
            :source   (atom.source)
            :compiled atom.compiled.output.code
            :derefs   atom.derefs }]
    (if atom.evaluated (set! frozen.value (atom.value)))
    (set! frozen.timestamp (Math.floor (Date.now)))
    frozen))

(defn run-atom [name]
  (Q.Promise (fn [resolve reject]
    (if (= -1 (.index-of (Object.keys ATOMS) name))
      (reject (str "No atom" name)))
    (resolve (evaluate-atom (aget ATOMS name))))))

(defn evaluate-atom [atom]
  (Q.Promise (fn [resolve reject]
    (try (resolve (evaluate-atom-sync atom))
      (catch e (reject e))))))

(defn evaluate-atom-sync [atom]
  ; compile atom code if not compiled yet
  (if (and atom.evaluated (not atom.outdated))
    atom
    (do
      (if (not atom.compiled) (compile-atom-sync atom))
      (let [code    atom.compiled.output.code
            context (runtime.make-context (path.resolve root-dir atom.name))]
        ; make loaded atoms available in context
        (.map (Object.keys ATOMS) (fn [i]
          (let [atom (aget ATOMS i)]
            (set! (aget context (translate atom.name)) atom))))
        ; add deref function and associated dependency tracking to context
        (let [deref-deps
                []
              deref-atom
                (fn deref-atom [atom]
                  (if (= -1 (deref-deps.index-of atom.name))
                    (deref-deps.push atom.name))
                  (if (and atom.evaluated (not atom.outdated))
                    (.value atom))
                    (.value (evaluate-atom-sync atom)))]
          (set! deref-atom.deps deref-deps)
          (set! context.deref deref-atom))
        ; add browserify require to context
        (if process.browser
          (set! context.require require))
        ; evaluate atom code
        (let [value (vm.run-in-context (runtime.wrap code) context { :filename atom.name })]
          ; if a runtime error has arisen, throw it upwards
          (if context.error
            (throw context.error)
            ; otherwise store the updated value and return the atom
            (do
              (set! atom.evaluated true)
              (atom.value.set value)
              atom)))))))

(defn get-deps [atom]
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
                (if (not dep) (throw (Error. (str "no atom" atom-name))))
                (derefs.push atom-name)
                (find-requires dep)
                (dep.derefs.map add-dep))))) ]
    (find-requires atom)
    (atom.derefs.map add-dep)
    { :derefs   derefs
      :requires requires }))

(defn- unique
  [arr]
  (let [encountered []]
    (arr.filter (fn [item]
      (if (= -1 (encountered.index-of item))
        (do
          (encountered.push item)
          true)
        false)))))
