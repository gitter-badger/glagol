(def ^:private is-equal (.-is-equal (require "wisp/runtime")))

(defn install-notion [notion-collection evaluate-notion tree-root full-path]
  (loop [notion-path   full-path
         current-dir tree-root]
    (if (= -1 (notion-path.index-of "/"))
      (add-notion evaluate-notion current-dir notion-path
        (aget notion-collection full-path))
      (let [child-dir (-> notion-path (.split "/") (aget 0))]
        (if (not (aget current-dir child-dir)) (aset current-dir child-dir {}))
        (recur (descend-path notion-path) (aget current-dir child-dir))))))

(defn descend-path [path]
  (-> path (.split "/") (.slice 1) (.join "/")))

(defn add-notion [evaluate-notion current-dir notion-name notion]
  (aset current-dir notion-name notion))

(defn get-notion-tree [notion-collection notion]
  (log.as :get-notion-tree notion.name)
  {})
