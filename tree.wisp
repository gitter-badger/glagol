(def ^:private chokidar (require "chokidar"))
(def ^:private fs       (require "fs"))
(def ^:private glob     (require "glob"))
(def ^:private is-equal (.-is-equal (require "wisp/runtime")))
(def ^:private notion   (require "./notion.wisp"))
(def ^:private path     (require "path"))
(def ^:private Q        (require "q"))

(defn make-notion-directory
  " NotionDirectory constructor. "
  [dir & opts]
  (let [dir
          (path.resolve dir)
        n
          { :type    "NotionDirectory"
            :name    (path.basename dir)
            :path    dir
            :notions {} }
        load
          #(.map (ignore-files (glob.sync %1 %2)) %3)]

    (if (fs.exists-sync n.path) (do
      ; load child notions
      (load (path.join n.path "*") { :nodir true }
        (fn [f] (let [f (notion.make-notion f)]
          (set! f.parent n) (aset n.notions f.name f))))
      ; load child notion directories
      (load (path.join n.path "*" path.sep) {}
        (fn [d] (let [d (make-notion-directory d)]
          (set! d.parent n) (aset n.notions d.name d))))))

    ; start watcher
    (if (= -1 (opts.index-of :nowatch)) (init-watcher! n))

    n))

(defn- ignore-files
  [files]
  (files.filter (fn [filename] (= -1 (filename.index-of "node_modules")))))

(defn- init-watcher! [n]
  (set! n.watcher (chokidar.watch n.path { :depth 0 :persistent false }))
  (n.watcher.on :change
    (fn [file]
      (let [changed (aget n.notions (path.basename file))]
        (.map [:source :compiled :value] #(aset changed._cache %1 nil)))))
  (n.watcher.on :add
    (fn [file]
      (if (= -1 (.index-of (keys n.notions) (path.basename file)))
        (aset n.notions (path.basename file) (notion.make-notion file)))))
  (n.watcher.on :addDir
    (fn [dir] (if (= -1 (.index-of (keys n.notions) (path.basename dir))) nil))))
      ;(log.as :adddir n.name dir)))))
      ;(if (= -1 (.index-of (keys n.notions) (path.basename dir))) (do
        ;(load (make-notion-directory dir)))))))


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
