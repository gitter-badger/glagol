(def ^:private Q (require "q"))
(set! Q.longStackSupport true)

(def ^:private chokidar  (require "chokidar"))
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

(defn start
  " Starts up the engine in a specified root directory. "
  ([dir] (start dir {}))
  ([dir opts]
    (let [dir
            (path.resolve dir)
          log
            (logging.get-logger "engine")
          state
            { :root    dir
              :tree    nil
              :watcher nil }]
      (-> (tree.load-notion-directory dir)
        (.then (fn [notions]
          (set! state.tree notions)
          (set! state.watcher (.watch (require "chokidar") ""))
          (watch-recursive state.watcher notions)
          (watcher.on :all (fn [] (log.as :watcher arguments)))
          (if opts.verbose (log.as :loaded-notion-tree notions))
          state))))))

(defn watch-recursive [watcher n]
  (cond
    (and (= n.type "Notion") n.path)
      (do (log 1) (watcher.add n.path))
    (and (= n.type "NotionDirectory") n.notions)
      (do (log 2) (.map (keys (or n.notions {})) (fn [n] (watch-recursive watcher n))))
    :else
      (do (log 3) (throw (Error. (str "unknown thing " n " in notion tree"))))))
