(def ^:private compiler (require "./compile"))
(def ^:private fs       (require "fs"))
(def ^:private glob     (require "glob"))
(def ^:private is-equal (.-is-equal (require "wisp/runtime")))
(def ^:private notion   (require "./notion"))
(def ^:private path     (require "path"))
(def ^:private Q        (require "q"))

(defn make-notion-directory
  " Creates a new NotionDirectory - a structure which corresponds
    to a filesystem directory and contains Notion references to its
    contents; as well as to the corresponding parent NotionDirectory,
    thus offering a view into the whole notion tree. "
  [notion-path]
  (log.as :make-notion notion-path "<DIR>")
  { :type "NotionDirectory"
    :name notion-path
    :path (path.resolve root-dir notion-path) })

(defn load-notion-directory
  [dir]
  (Q.Promise (fn [resolve reject]
    (glob (path.join dir "*") {} (fn [err files]
      (set! files (ignore-files files))
      (if err (reject err))
      (resolve (Q.allSettled (files.map (fn [file]
        (Q.Promise (fn [resolve reject]
          (fs.stat file (fn [err stats]
            (if err (reject err)
              (resolve (if (stats.is-directory)
                (load-notion-directory file)
                (notion.load-notion file)) )))))))))))))))

(defn freeze-notion-directory
  " Returns a static snapshot of all loaded notions. "
  []
  (let [snapshot {}]
    (.map (keys NOTIONS) (fn [i]
      (let [frozen (freeze-notion (aget NOTIONS i))]
        (aset snapshot i frozen))))
    snapshot)
    (= notion.type "NotionDirectory")
      { :name      notion.name
        :type      "NotionDirectory"
        :path      (path.relative root-dir notion.path)
        :timestamp (Math.floor (Date.now)) })

(defn- ignore-files
  [files]
  (files.filter (fn [filename] (= -1 (filename.index-of "node_modules")))))

;(defn install-notion
  ;[notion-collection evaluate-notion tree-root full-path]
  ;(loop [notion-path   full-path
         ;current-dir tree-root]
    ;(if (= -1 (notion-path.index-of "/"))
      ;(add-notion evaluate-notion current-dir notion-path
        ;(aget notion-collection full-path))
      ;(let [child-dir (-> notion-path (.split "/") (aget 0))]
        ;(if (not (aget current-dir child-dir)) (aset current-dir child-dir {}))
        ;(recur (descend-path notion-path) (aget current-dir child-dir))))))

(defn install-notion [resolve notion]
  (loop [notion-path   notion.name
         current-dir NOTIONS]
    (if (= -1 (notion-path.index-of "/"))
      (do
        (add-notion compiler.evaluate-notion current-dir notion-path notion)
        (resolve notion))
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
    (resolve (compiler.evaluate-notion (descend-tree NOTIONS notion-path))))))
