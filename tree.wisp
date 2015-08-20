(def ^:private is-equal (.-is-equal (require "wisp/runtime")))

(defn install-atom [atom-collection evaluate-atom tree-root full-path]
  (loop [atom-path   full-path
         current-dir tree-root]
    (if (= -1 (atom-path.index-of "/"))
      (add-atom evaluate-atom current-dir atom-path
        (aget atom-collection full-path))
      (let [child-dir (-> atom-path (.split "/") (aget 0))]
        (if (not (aget current-dir child-dir)) (aset current-dir child-dir {}))
        (recur (descend-path atom-path) (aget current-dir child-dir))))))

(defn descend-path [path]
  (-> path (.split "/") (.slice 1) (.join "/")))

(defn add-atom [evaluate-atom current-dir atom-path atom]
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

(defn get-atom-tree [atom-collection atom]
  (log atom)
  {})
