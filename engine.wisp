(def ^:private Q (require "q"))
(set! Q.longStackSupport true)

(def ^:private colors    (require "colors/safe"))
(def ^:private detective (require "detective"))
(def ^:private logging   (require "etude-logging"))
(def ^:private resolve   (require "resolve"))
(def ^:private runtime   (require "./runtime.js"))
(def ^:private url       (require "url"))
(def ^:private vm        (require "vm"))

(def notion (require "./notion.wisp"))
(def tree   (require "./tree.wisp"))

(def ^:private = runtime.wisp.runtime.is-equal)

(def log (logging.get-logger "engine"))

(defn start
  " Starts up the engine in a specified root directory. "
  [dir]
  (let [state
    { :root    dir
      :tree    {}
      :events  (new (.-EventEmitter2 (require "eventemitter2"))
                 { :maxListeners 32 :wildcard true })
      :watcher { :add (fn []) :on (fn []) } }]
    ;(if (not process.browser)
        ;(let [chokidar (require "chokidar")]
        ;(set! watcher (chokidar.watch "" { :persistent true :alwaysStat true }))))
    (-> (tree.load-notion-directory dir)
      (.then (fn [notions]
        ;; TODO these here too
        ;; (updated notion :value)
        ;; (watcher.add notion-path)
        ;; emit event on value update
        ;; (notion.value (updated.bind nil notion :value))
        (set! state.tree notions)
        (log.as :loaded-notion-tree notions)
        state)))))
