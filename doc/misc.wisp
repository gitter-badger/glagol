;;; ZA CHERNI DNI
;;;
;;; various pieces
;;; which fell out along the way
;;; might be used one day...

;;; directory navigation

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

;;; old freezing and browserify-friendly dependency management

(defn freeze-notion
  " Returns a static snapshot of a single notion. "
  [notion]
  (cond
    (= notion.type "Notion")
      (let [frozen
              { :type     "Notion"
                :name     notion.name
                :path     notion.path
                :source   (notion.source)
                :compiled notion.compiled.output.code }]
        (if notion.evaluated (set! frozen.value (notion.value)))
        (set! frozen.timestamp (Math.floor (Date.now)))
        frozen)))

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

(defn- step? [node]
  (and
    (= node.type "MemberExpression")
    (= node.object.type "Identifier")
    (or (= node.object.name "_") (= node.object.name "__"))))

(defn- get-next-notion [node notion path]
  (if (and node.parent (= node.parent.type "MemberExpression"))
    (let [next-notion (tree.resolve notion path)]
      (or next-notion false))))

(defn- detected!
  [node value]
  ; replacing the node with a literal in detective's copy of the ast
  ; allows detective to fish out the end value by itself afterwards
  (set! node.arguments [{ :type "Literal" :value value }])
  true)

(defn- detect-and-parse-deref
  " Hacks detective module to find `_.<notion-name>`
    expressions (as compiled from `./<notion-name>` in wisp). "
  [notion node]
  (set! node.arguments (or node.arguments []))
  (if (step? node)
    (loop [step node
           path (if (= node.object.name "_") "." "..")]
      (let [next-path (conj path "/" step.property.name)]
        (log next-path)
        (let [next-notion (get-next-notion step notion next-path)]
          (if next-notion (recur step.parent next-path)
                          (detected! node next-path)))))
    false))

(defn- find-derefs
  " Returns a list of notions referenced from a notion. "
  [notion]
  (cond
    (= notion.type "Notion")
      (let [detective (require "detective")
            compiled  (or notion.compiled
                        (.-compiled (compile-notion-sync notion)))
            code      compiled.output.code
            results   (detective.find code
                      { :word      ".*"
                        :isRequire (detect-and-parse-deref.bind nil notion) })]
        (log.as :derefs-of notion.name (util.unique results.strings))
        (util.unique results.strings))
    (= notion.type "NotionDirectory")
      []))

(defn- find-requires
  [requires notion]
  (cond
    (= notion.type "Notion")
      (notion.requires.map (fn [req]
        (let [resolved
                (.sync (require "resolve") req
                  { :basedir    (path.dirname notion.path)
                    :extensions [".js" ".wisp"] })]
          (if (= -1 (requires.index-of resolved))
            (requires.push resolved)))))
    (= notion.type "NotionDirectory")
      []))

(defn- add-dep
  [deps reqs from to]
  (let [full-from (tree.get-path from)
        full-to   (path.resolve full-from to)]
    (log.as :add-dep full-from full-to)
    (if (= -1 (deps.index-of full-to))
      (let [dep (tree.resolve from to)]
        (if (not dep) (throw (Error.
          (str "No notion " to " (from " from.name ")"))))
        (deps.push full-to)
        (find-requires reqs dep)
        (map (fn [to] (add-dep deps reqs dep to)) (find-derefs dep))))))

(defn get-deps
  " Returns a processed list of the dependencies of a notion. "
  [notion]
  (log.as :get-deps notion.path)
  (let [reqs []  ;; native library requires
        deps []] ;; notion dependencies a.k.a. derefs
    (find-requires reqs notion)
    (.map (find-derefs notion)
      (fn [notion-name] (add-dep deps reqs notion notion-name)))
    { :derefs   deps
      :requires reqs }))

;;
;; utilities
;;

(defn unique
  " Filters an array into a set of unique elements. "
  [arr]
  (let [encountered []]
    (arr.filter (fn [item]
      (if (= -1 (encountered.index-of item))
        (do
          (encountered.push item)
          true)
        false)))))
