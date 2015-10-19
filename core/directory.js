var path = require('path')
  , fs   = require('fs');

var glob     = require('glob')
  , chokidar = require('chokidar');

var Script = require('../core/script.js');

var Directory = module.exports = function Directory (dirPath, options) {

  // TODO: uniform interface for Script and Directory!
  //       pass directory options in place of srcData!

  // enforce usage of `new` keyword even if omitted
  if (!(this instanceof Directory)) return new Directory(dirPath, options);

  options = options || {};

  this.type  = "Directory";
  this.path  = path.resolve(dirPath);
  this.name  = path.basename(this.path);
  this.nodes = {};

  if (fs.existsSync(this.path)) {
    this._load("*", { nodir: true }, Script);
    this._load(path.join("*", path.sep), {}, Directory);
  }

  if (!options.nowatch) this._watch();

}

Directory.prototype._load = function (rel, opts, type) {

  glob.sync(path.join(this.path, rel), opts)
    .filter(function (f) {
      return -1 === f.indexOf('node_modules');
    }).map(function (f) {
      var s = type(f);
      s.parent = this;
      this.nodes[s.name] = s;
    }, this);

}

Directory.prototype._watch = function () {

  this._watcher = chokidar.watch(this.path, { depth: 0, persistent: false });

  this._watcher.on("change", function (f) {
    this.nodes[path.basename(f)].refresh();
  }.bind(this))

  this._watcher.on("add", function (f) {
    if (-1 === Object.keys(this.nodes).indexOf(path.basename(f))) {
      this.nodes[path.basename(f)] = Script(f);
    };
  }.bind(this));

}
