;(def ^:private compiler (require "./compile"))
(def ^:private fs       (require "fs"))
(def ^:private glob     (require "glob"))
(def ^:private is-equal (.-is-equal (require "wisp/runtime")))
(def ^:private notion   (require "./notion.wisp"))
(def ^:private path     (require "path"))
(def ^:private Q        (require "q"))

;;; directory constructor, loader, and serializer

(defn make-notion-directory
  [dir]
  (let [dir   (path.resolve dir)
        hindu (.watch (require "chokidar") dir)]
    { :type    "NotionDirectory"
      :name    (path.basename dir)
      :path    dir
      :notions (load dir)
      :watcher (.watch (require "chokidar") dir) }))

(defn- load [dir]
  (let [notions {}]
    (if (fs.exists-sync dir) (do
      (.map (ignore-files (glob.sync (path.join dir "*")) { :nodir true })
        (fn [f] (let [n (notion.make-notion f)] (aset notions n.name n))))
      (.map (ignore-files (glob.sync (path.join dir "*" path.sep))) (fn [d]
        (let [d (make-notion-directory d)] (aset notions d.name d))))))
    notions))

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

(defn resolve [self target-path]
  ; doesn't work with parentless notions
  (if (not self.parent)
    (throw (Error. (str "can't use relative paths (such as " target-path
      ") from notion " self.name ", because it has no parent set."))))

  (let [split-path
          (target-path.split "/")
        first-token
          (aget split-path 0)]

    (log.as :resolve self.path target-path)

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
