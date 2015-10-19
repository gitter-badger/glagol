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

function getter (k) {
  return this._cache[k] === undefined
    ? this[operations[k]]()
    : self.cache[k];

  var operations = { source: "load", compiled: "compile", value: "evaluate" };
}

function setter (k) {
  this.cache[k] = v;
}

Script.prototype.load = function () {
  return this.path
    ? this.source = fs.readFileSync(this.path, "utf8")
    : undefined;
}

Script.prototype.compile = function () {
  return this.source
    ? this.compiled = runtime.compileSource(this.source, this.name)
    : undefined
}

Script.prototype.evaluate = function () {
  return (this._cache.value !== undefined)
    ? this._cache.value
    : (this.source && this.compiled && this.compiled.output && this.compiled.output.code)
      ? (function(){
          var context = this.makeContext()
            , src     = runtime.wrap(this.compiled.output.code)
            , result  = vm.runInContext(src, context, { filename: notion.path });
          if (context.error) throw context.error;
          return this._cache.value = result;
        }).bind(this)() : undefined;
}

Script.prototype.refresh = function () {
  ["source", "compiled", "value"].map(function (k) {
    this._cache[k] = undefined;
  }, this);
}

Script.prototype.makeContext = function () {
  var p    = this.path
    , tree = require('./tree.js').getTree(this)
    , ctx  = runtime.makeContext(p);

  ctx.process.cwd = function () { return path.dirname(p) };
  ctx.log = logging.getLogger("@".bold + this.name);
  ctx.self = this;
  ctx._  = tree;
  ctx.__ = tree.__;

  return ctx;
}
