module.exports =
  { compileSource: compileSource
  , makeContext:   makeContext
  , requireWisp:   requireWisp
  , wrap:          wrap };

var fs      = require('fs')
  , logging = require('etude-logging')
  , path    = require('path')
  , resolve = require('resolve')
  , vm      = require('vm');

var wisp = module.exports.wisp =
  { ast:      require('wisp/ast.js')
  , compiler: require('wisp/compiler.js')
  , runtime:  require('wisp/runtime.js')
  , sequence: require('wisp/sequence.js') };

// patch translate-identifier-word to translate
// slashes into nested namespace references
var _translate = require('wisp/backend/escodegen/writer.js').translateIdentifierWord;
require('wisp/backend/escodegen/writer.js').translateIdentifierWord = function () {
  var id = _translate.apply(null, arguments);
  return id.split('/').join('._.');
}

var log = logging.getLogger('runtime');

function compileSource (source, filename, raw) {
  raw = raw || false;
  var forms     = wisp.compiler.readForms(source, filename)
    , forms     = forms.forms;

  var processed = wisp.compiler.analyzeForms(forms)
  if (processed.error) {
    throw new Error("Compile error in " + filename + ": " + processed.error);
  }

  var options   = { 'source-uri': filename , 'source': source }
    , output    = wisp.compiler.generate.bind(null, options).apply(null, processed.ast);

  return { forms: forms, processed: processed, output: output }
}

function wrap (code, map) {
  // TODO make source maps work
  var sep = "//# sourceMappingURL=data:application/json;base64,";
  var mapped = code.split(sep);
  return (!map ? [] : [
    'require("source-map-support").install({retrieveSourceMap:function(){',
    'return{url:null,map:"', mapped[1].trim(), '"}}});'
  ]).concat([
    'error=null;try{', mapped[0],
    '}catch(e){error=e}',
  ]).join("");
}

function importIntoContext (context, obj) {
  Object.keys(obj).map(function(k) { context[k] = obj[k] });
}

function makeContext (filename, elevated) {

  function _require (module) {
    module = resolve.sync(module,
      { extensions: [".js", ".wisp"]
      , basedir:    path.dirname(filename) });
    if (!process.browser && path.extname(module) === '.wisp') {
      return requireWisp(module)
    } else {
      return require(module)
    }
  };
  _require.main = require.main;

  var context =
    { exports:      {}
    , __dirname:    path.dirname(filename)
    , __filename:   filename
    , log:          logging.getLogger(path.basename(filename))
    , use:          requireWisp
    , process:      { cwd: process.cwd() }
    , isInstanceOf: function (type, obj) { return obj instanceof type }
    , require:      _require };

  if (elevated) {
    context.process = process;
    context.require = require;
  }

  if (process.browser) {
    ATOM_NAMES.map(function (atomName) {
      if (context[atomName]) console.log(
        "Warning: overriding existing key", atomName, "in context", name);
      context[atomName] = global[atomName];
    })
  }

  [ wisp.ast
  , wisp.sequence
  , wisp.runtime ].map(importIntoContext.bind(null, context));

  return vm.createContext(context);
}

var cache = module.exports.cache = [];

function requireWisp (name, raw, elevated) {
  var basedir  = path.dirname(require('resolve/lib/caller.js')())
    , filename = resolve.sync(name, { extensions: [".wisp"], basedir: basedir })

  // HACK: require calls to different locations of engine.wisp returns
  // different instances of the module -- which, however, is stateful;
  // and the state is missing everywhere except the original location.
  // currently, all instances of the `etude-engine` module are symlinks
  // to the same location, so a call to realpath(2) will give us the
  // correct cache key. however, the existence of this issue means that
  // engine should either not be a stateful module or store its state
  // globally or something.
  filename = fs.realpathSync(filename);

  if (!cache[filename]) {
    var source   = fs.readFileSync(filename, { encoding: 'utf8' })
      , output   = compileSource(source, filename, raw || false).output
      , context  = makeContext(filename, elevated);
    vm.runInContext(wrap(output.code), context, { filename: name });
    if (context.error) throw context.error;
    cache[filename] = context.exports;
  }
  return cache[filename];
}
