(def ^:private ee2    (require "eventemitter2"))
(def ^:private fs     (require "fs"))
(def ^:private observ (require "observ"))
(def ^:private path   (require "path"))
(def ^:private Q      (require "q"))

(defn make-notion
  " A Notion corresponds to a source code file;
    it contains its contents, the result of its
    transpilation to JavaScript, and the result
    of its last evaluation.

    Passing a preloaded source is optional. "
  [notion-path source-text]
  (let [events      (ee2.EventEmitter2.)
        notion-path (or notion-path "")
        pipeline    { :loaded    nil
                      :compiled  nil
                      :evaluated nil }
        notion      { :type      "Notion"
                      :path      notion-path
                      :name      (path.basename notion-path)
                      :events    events
                      :requires  []
                      :evaluated false
                      :outdated  false
                      :parent    nil }]

    (.map (keys pipeline) (add-observable-property!.bind nil notion pipeline))

    (cond
      source-text (set! pipeline.loaded source-text)
      notion-path (fs.read-file notion-path :utf-8 (fn [err source-file]
        (if err (throw err)) (set! notion.loaded source-file))))

    notion))

(defn- add-observable-property! [notion pipeline i]
  (Object.define-property notion i
    { :configurable true
      :enumerable   true
      :get (fn []
        (aget pipeline i))
      :set (fn [v]
        (aset pipeline i v) (notion.events.emit i [notion v])) }))

(defn load-notion
  " Loads a notion from the specified path, and adds it to the watcher. "
  [notion-path]
  ;(log.as :load-notion notion-path)
  (Q.Promise (fn [resolve reject]
    (fs.read-file notion-path "utf-8" (fn [err src]
      (if err (reject err) (resolve (make-notion notion-path src))))))))

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

;(watcher.on "change" reload-notion)

;(defn reload-notion
  ;" Reloads a notion's source code from a file.
    ;TODO: pass notion instead of path? "
  ;[notion-path file-stat]
  ;(fs.read-file notion-path "utf-8" (fn [err src]
    ;(if err (do (log err) (throw err)))
    ;(let [rel-path    (path.relative root-dir notion-path)
          ;notion-name (translate rel-path)
          ;notion      (aget NOTIONS notion-name)]
      ;(if (not (= src (notion.source))) (notion.source.set src))))))

(def translate
  (.-translate-identifier-word (require "wisp/backend/escodegen/writer.js")))
