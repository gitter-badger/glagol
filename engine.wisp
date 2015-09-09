(def ^:private path (require "path"))

(def notion  (require "./notion.wisp"))
(def runtime (require "./runtime.js"))
(def tree    (require "./tree.wisp"))

(defn start
  " Starts up an engine instance in a specified root directory. "
  ([dir]
    (start dir {}))
  ([dir opts]
    { :root    (path.resolve dir)
      :tree    (tree.make-notion-directory dir)
      :watcher nil }))
