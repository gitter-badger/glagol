;(def ^:private compiler (require "./compile"))
(def ^:private fs       (require "fs"))
(def ^:private glob     (require "glob"))
(def ^:private is-equal (.-is-equal (require "wisp/runtime")))
(def ^:private notion   (require "./notion.wisp"))
(def ^:private path     (require "path"))
(def ^:private Q        (require "q"))

;;; directory constructor, loader, and serializer

(defn make-notion-directory
  " Creates a new NotionDirectory - a structure which corresponds
    to a filesystem directory and contains Notion references to its
    contents; as well as to the corresponding parent NotionDirectory,
    thus offering a view into the whole notion tree. "
  [dir notion-list]
  (let [notions    {}
        notion-dir { :type    "NotionDirectory"
                     :name    (path.basename dir)
                     :path    dir
                     :notions notions }]
    (notion-list.map (fn [notion]
      (set! notion.parent notion-dir)
      (aset notions notion.name notion)))
    notion-dir))

(defn load-notion-directory
  [dir]
  (let [dir (path.resolve dir)]
    (Q.Promise (fn [resolve reject]
      (if (not (fs.exists-sync dir)) (reject (str dir " does not exist")))
      (glob (path.join dir "*") {} (fn [err files]
        (log.as :glob dir files)
        (set! files (ignore-files files))
        (if err (reject err))
        (.then (Q.allSettled (files.map (fn [file]
          (Q.Promise (fn [resolve reject]
            (fs.stat file (fn [err stats]
              (if err (reject err)
                (resolve (if (stats.is-directory)
                  (load-notion-directory file)
                  (notion.load-notion file)) )))))))))
          (fn [results]
            (resolve (make-notion-directory dir
              (results.map #(.-value %1))))))))))))

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


;;; directory navigation

(defn descend [tree path]
  (loop [current-node   tree
         path-fragments (path.split "/")]
    ; error checking; TODO throw when trying to descend down a file
    (if (> path-fragments.length 0)
      (do
        (if (= -1 (.index-of (keys current-node.notions) (aget path-fragments 0)))
          (throw (Error. (str "No notion at path " path))))
        (recur
          (aget current-node.notions (aget path-fragments 0))
          (path-fragments.slice 1)))
      current-node)))

(defn get-root [notion]
  (loop [n notion]
    (if n.parent (recur n.parent)
      n)))

(defn get-path [notion]
  (loop [n notion
         p ""]
    (if n.parent
      (recur n.parent (conj n.name "/" p))
      (conj "/" p))))

(defn get-notion-by-path [self target-path]
  ; doesn't work with parentless notions
  (if (not self.parent)
    (throw (Error. (str "can't use relative paths (such as " target-path
      ") from notion " self.name ", because it has no parent set."))))

  (let [split-path
          (target-path.split "/")
        first-token
          (aget split-path 0)]

    (log.as :get-notion-by-path self.path target-path)

    (if (= -1 (.index-of ["" "." ".."] first-token))
      (throw (Error. (str
        first-token " is not a valid first token"
        " for the notion path " target-path
        " (from " self.name ")"))))

    (if (and (= first-token "..") (not self.parent.parent))
      (throw (Error. (str "can't find a parent for notion "
        self.parent.name " (which is parent of " self.name ")"))))

    ; descend rest of path
    (loop [n    (cond (= first-token "")  (get-root self)
                      (= first-token ".")  self.parent
                      (= first-token "..") self.parent.parent)
           tail (split-path.slice 1)]
      (let [next-path-token (aget tail 0)
            err (fn [& args] (throw (Error. (apply str n.name " " args))))]
        (if (not next-path-token)
          n ; if there's no more to the path, return this
          ; otherwise, y'know, recurse one directory down
          (cond ; error handling
            (or (not n) (not (= n.type "NotionDirectory"))) n
            (not n.notions) (err "has no child notion list")
            :else (recur (aget n.notions (aget tail 0)) (tail.slice 1))))))))
