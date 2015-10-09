(defn freeze [n]
  (merge { :name n.name :time (timestamp)}
    (cond
      (= n.type "Notion")
        { :type "FrozenNotion"
          :code n.compiled.output.code }
      (= n.type "NotionDirectory")
        { :type "FrozenNotionDirectory"
          :notions (n.notions.map freeze) }
      :else
        (throw (Error. (str "tried to freeze unknown thing"))))))

(defn- timestamp [] (String (Date.now)))

; TODO ; TODO ; TODO ; TODO ; TODO ; TODO ; TODO ; 
;
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

