(def ^:private Q (require "q"))
(set! Q.longStackSupport true)

(def ^:private colors    (require "colors/safe"))
(def ^:private logging   (require "etude-logging"))
(def ^:private path      (require "path"))
(def ^:private resolve   (require "resolve"))
(def ^:private url       (require "url"))
(def ^:private vm        (require "vm"))

(def compile (require "./compile.wisp"))
(def notion  (require "./notion.wisp"))
(def runtime (require "./runtime.js"))
(def tree    (require "./tree.wisp"))

(def ^:private = runtime.wisp.runtime.is-equal)

(def log )

(defn start
  " Starts up the engine in a specified root directory. "
  ([dir] (start dir {}))
  ([dir opts]
    (let [log
            (logging.get-logger "engine")
          engine-state
            { :root    (path.resolve dir)
              :tree    {}
              :watcher { :add (fn []) :on (fn []) } }]
      (-> (tree.load-notion-directory dir)
        (.then (fn [notions]
          (set! engine-state.tree notions)
          (if opts.verbose (log.as :loaded-notion-tree notions))
          engine-state))))))
