var path = require('path')
  , fs   = require('fs')
  , vm   = require('vm');

var Script = module.exports = function Script (srcPath, srcData) {

  // enforce usage of `new` keyword even if omitted
  if (!(this instanceof Script)) return new Script(srcPath, srcData);

  // define basic properties
  this.type   = "Script";
  this.path   = srcPath || "";
  this.name   = path.basename(this.path);
  this.parent = null;
  this._cache =
    { source:   typeof srcData === 'string' ? srcData : undefined
    , compiled: undefined
    , value:    undefined };

  this.runtime = null;

  switch (path.extname(this.path)) {
    case '.js':
      this.runtime = require('../runtimes/javascript.js');
      break;
    case '.wisp':
      this.runtime = require('../runtimes/wisp.js');
      break;
  }

  // define "smart" properties
  // these comprise the core of the live updating functionality:
  // the script's source is loaded, processed, and updated on demand
  Object.keys(this._cache).map(function (k) {
    Object.defineProperty(this, k,
      { configurable: true
      , enumerable:   true
      , get: getter.bind(this, k)
      , set: setter.bind(this, k) });
  }, this);

}

var operations = { source: "load", compiled: "compile", value: "evaluate" };

function getter (k) {
  return this._cache[k] === undefined
    ? this[operations[k]]()
    : this._cache[k];
}

function setter (k, v) {
  this._cache[k] = v;
}

Script.prototype.load = function () {
  return this.path
    ? this.source = fs.readFileSync(this.path, "utf8")
    : undefined;
}

Script.prototype.compile = function () {
  return this.source
    ? this.runtime
      ? this.compiled = this.runtime.compileSource(this.source, this.name)
      : this.source
    : undefined
}

Script.prototype.evaluate = function () {
  return (this._cache.value !== undefined)
    ? this._cache.value
    : (this.source && this.compiled)
      ? this.runtime
        ? (function(){
            var context = this.makeContext()
              , src     = this.compiled
              , result  = vm.runInContext(src, context, { filename: this.path });
            if (context.error) throw context.error;
            return this._cache.value = result;
          }).bind(this)()
        : this.compiled
      : undefined;
}

Script.prototype.refresh = function () {
  ["source", "compiled", "value"].map(function (k) {
    this._cache[k] = undefined;
  }, this);
}

Script.prototype.makeContext = function () {
  var ctx  = this.runtime.makeContext(this)
    , tree = this.parent ? require('./tree.js')(this) : {};

  ctx._  = tree;
  ctx.__ = tree.__;

  return vm.createContext(ctx);
}

Script.prototype.freeze = function () {

  return { name: this.name
         , time: String(Date.now()) 
         , code: this.compiled };

}
