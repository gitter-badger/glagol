(def ^:private Q (require "q"))

(defn make-notion
  " Creates a new Notion - an atom-type structure
    corresponding to a source code file but also
    containing its transpiled JS form and the result
    of its last evaluation.

    Passing a preloaded source is optional. "
  [notion-path source]
  (let [notion
          { :type      "Notion"
            :path      (path.resolve root-dir notion-path)
            :name      notion-path
            :source    (observ (.trim (or source "")))
            :compiled  nil
            :requires  []
            :value     (observ undefined)
            :evaluated false
            :outdated  false }]

    ; emit event on value update
    (notion.value (updated.bind nil notion :value))

    notion))

(defn load-notion
  " Loads a notion from the specified path, and adds it to the watcher. "
  [notion-path i arr]
  (Q.Promise (fn [resolve reject]
    (let [rel-path (path.relative root-dir notion-path)]
      (fs.read-file notion-path "utf-8" (fn [err src]
        (if err
          (if (= err.code "EISDIR")
            (resolve (load-notion-directory notion-path))
            (do (log err) (reject err)))
          (let [notion (make-notion rel-path src)]
            (install-notion resolve notion)))))))))

(defn freeze-notion
  " Returns a static snapshot of a single notion. "
  [notion]
  (cond
    (= notion.type "Notion")
      (let [frozen
              { :name     notion.name
                :type     "Notion"
                :path     (path.relative root-dir notion.path)
                :source   (notion.source)
                :compiled notion.compiled.output.code }]
        (if notion.evaluated (set! frozen.value (notion.value)))
        (set! frozen.timestamp (Math.floor (Date.now)))
        frozen)))

;(watcher.on "change" reload-notion)

(defn reload-notion
  " Reloads a notion's source code from a file.
    TODO: pass notion instead of path? "
  [notion-path file-stat]
  (fs.read-file notion-path "utf-8" (fn [err src]
    (if err (do (log err) (throw err)))
    (let [rel-path  (path.relative root-dir notion-path)
          notion-name (translate rel-path)
          notion      (aget NOTIONS notion-name)]
      (if (not (= src (notion.source))) (notion.source.set src))))))

(def translate
  (.-translate-identifier-word (require "wisp/backend/escodegen/writer.js")))
