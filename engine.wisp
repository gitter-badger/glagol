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
        (.then (fn [root-notion]
          (set! state.tree root-notion)
          (set! state.watcher (.watch (require "chokidar") ""))
          (watch-recursive state.watcher root-notion)
          (if opts.verbose (log.as :loaded-notion-tree root-notion))
          state))))))

(defn watch-recursive [watcher n]
  (cond
    (and (= n.type "Notion") n.path)
      (watcher.add n.path)
    (and (= n.type "NotionDirectory") n.notions)
      (.map (keys (or n.notions {}))
        (fn [i] (watch-recursive watcher (aget n.notions i))))
    :else
      (throw (Error. (str "unknown thing " n " in notion tree")))))
