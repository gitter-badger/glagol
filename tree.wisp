(defn make-tree-from-atoms [atoms])

(defn make-tree-from-bundle [bundle])

(defn- descend-path [path]
  (-> path (.split "/") (.slice 1) (.join "/")))

(defn install-atom [tree-root atom-collection full-path]
  (loop [atom-path   full-path
         current-dir tree-root]
    (if (= -1 (atom-path.index-of "/"))
      (add-atom (aget atom-collection full-path)))
      (recur
        (descend-path atom-path)
        (let [next-dir (-> path (.split "/") (aget 0))]
          (if (not (aget current-dir next-dir))
            (aset current-dir next-dir {}))
          (aget current-dir next-dir)))))

(defn add-atom [current-dir atom-path atom]
  (Object.define-property current-dir atom-path
    { :enumerable   true
      :configurable true
      :get
        (fn []
          (cond
            (= atom.type "Atom") (do
              (if (not (atom.has-own-property "value")) (evaluate-atom atom))
              (atom.value))
            (= atom.type "AtomDirectory")
              {}))
      :set
        (fn [new-value]
          (atom.value.set new-value))}))
