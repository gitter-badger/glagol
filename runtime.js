/* **runtime.md** is currently the only **JavaScript** file of the core bunch.
   It contains a few basic functions that allow for bootstrapping into a state
   that is able to execute [Wisp](./wisp.md) code that is itself compiled at
   runtime, furthemore without using the ominously yet unexplainedly deprecated
   [require.extensions](https://nodejs.org/api/all.html#all_require_extensions).

   I am not sure at all what happens with Wisp namespace imports (TODO: check).
   Everything works just swimmingly over plain Node `require`s; it's a little
   too cumbersome to type out the `(def ^:private library (require "library"))`
   but a `(def-` is just one patch away in one subsequent section of this file.

   Let's state it loud and clear what we can offer the world: */

module.exports =
  { compileSource: compileSource
  , makeContext:   makeContext
  , requireWisp:   requireWisp
  , wrap:          wrap };

/* And here's what we don't tell 'em we need for that: */

var fs      = require('fs')
  , path    = require('path')
  , resolve = require('resolve')
  , vm      = require('vm');

/* Including a logger from [etude-logging](github.com/egasimus/etude-logging) */
var logging = require('etude-logging')
  , log = logging.getLogger('runtime');

/* And, most notably, most of Wisp: ... */

var wisp = module.exports.wisp =
  { ast:      require('wisp/ast.js')
  , compiler: require('wisp/compiler.js')
  , expander: require('wisp/expander.js')
  , runtime:  require('wisp/runtime.js')
  , sequence: require('wisp/sequence.js')
  , string:   require('wisp/string.js')};

/* First thing we do before being asked to compile any Wisp yet,
   is install a few compiler hacks that I'd like to be available
   everywhere throughout the runtime environment and haven't yet
   beel cleanly implemented from Wisp.

   Some of these might constitute suggested future patches to
   the main [Wisp](https://github.com/Gozala/wisp) codebase. (TODO: check)

   For example, we enable the arrow macro, which threads
   an argument through nested functions like this:

   > (-> a (b) (c 2) (d a)) ===>
       (d a (c 2 (b a)))

   This is being done all on the lexical level so don't
   expect it to be as clever as you don't need to be really.
   E.g. a lambda would need to be wrapped in double skobki
   which is ugly but works in a pinch, especially if you end up
   cramming half a library into that lambda:

   > (-> 2 ((fn [x] (+ x 2))) ((fn [x] (str x " oz")))) ===>
       ((fn [x] (str x " oz") ((fn [x] (+ x 2)) 2))

     ; 4oz

   The following implementation of the arrow "native" macro is taken
   directly from [Wisp docs](https://github.com/Gozala/wisp/blob/master/Readme.md#another-macro-example)
   and rewritten into JavaScript using some of [Wisp's sequence functions](https://github.com/Gozala/wisp/blob/master/src/sequence.wisp),
   which are modeled after Clojure's and implement soft immutability simply --
   by avoiding to modify things in place. */

wisp.expander.installMacro("->", function to () {
  var operations = Array.prototype.slice.call(arguments, 0);
  var s = wisp.sequence;
  return s.reduce(function (form, op) {
    return s.cons(s.first(op), s.cons(form, s.rest(op)))
  }, s.first(operations), s.rest(operations));
});

/* Wrapped in an immediately called local function so as not to pollute
   the namespace, here go these wretched writer monkeypatches: */

(function () {
  var _writer = require('wisp/backend/escodegen/writer.js');

/* By default, Wisp translates `(foo/bar/baz)` (a namespaced function call,
   with the `/` being roughly equivalent to a JS `.`, only with nested
   namespaces -- something that neither Wisp nor IIRC Clojure support --
   to the nonsencical `foo.bar/baz`. The following patch makes it produce
   the more consistent result `foo.bar.baz`, which accidentally is perfect
   for implementing a file tree equivalent for each Notion. 

   This is how in a Notion the identifier `../options/setting` is made to
   return the value of the notion at the corresponding filesystem path,
   relative to the calling notion. Note that only the language construct is
   available runtime-wide; the functionality is not available from non-Notion
   code (basically any code that comes into being by being `require`d). 

   Strangely enough it also seems to be a magic/more magic switch, since to
   the cursory inspection the function seems to be doing nothing, yet things
   seemed to break last time I messed with it. TODO: check */

  var _translate = _writer.translateIdentifierWord;
  _writer.translateIdentifierWord = function () {
    var id = _translate.apply(null, arguments);
    return id;
  }

/* And this gets rid of an unnecessary limitation in function declaration order.
   It changes the way Wisp compiled (fn foo [] :bar) top-level local functions;
   the `var ...` part in `var foo = function foo () { return "bar" }` is not
   really necessary, but when present it prevents local functions from seeing
   things declared either before or after them; also themselves, which used to
   make recursion painful.

   A similar patch is likely needed for locals since, in the following code:
   `(let [foo (fn foo [] (foo))])`, `foo` cannot actually call itself.
   So you can see the following workaround in some places:
   `(let [foo nil] (set! foo (fn [] (foo))))`. TODO

   This is also where the `(def-` patch shorthand for `(def ^:private`
   should probably go in. TODO

   There's also a typo carried over from upstream: `originam-form` should
   instead be `original-form` in the originam code. TODO upstream PR */

  var _writeDef = _writer.writeDef;
  _writer.__writers__.def = _writer.writeDef = function (form) {
    var isPrivateDefn = form.init.op === 'fn' && !form.export;;
    return isPrivateDefn ?
      wisp.sequence.conj(
        wisp.sequence.assoc(
          _writer.write(form.init), 'type', 'FunctionDeclaration'),
        _writer.writeLocation(
          (form || 0)['form'], (form || 0)['originam-form'])
      ) : _writeDef(form);
  }
})();

function compileSource (source, filename, raw) {
  //log.as("compiling", filename);
  raw = raw || false;
  var forms     = wisp.compiler.readForms(source, filename)
    , forms     = forms.forms;

  var processed = wisp.compiler.analyzeForms(forms)
  if (processed.error) {
    var msg = "Wisp analyzer error in " + filename + ":\n  " + processed.error;
    console.log(msg, "\n  ->", processed.error.line, processed.error.column)
    throw new Error(msg);
  }

  var options = { 'source-uri': filename || "<???>" , 'source': source }
    , output  = wisp.compiler.generate.bind(null, options)
                  .apply(null, processed.ast);
  if (output.error) {
    throw new Error("Wisp compiler error in " + filename + ": " + processed.error)
  }

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

  var browser = Boolean(process.browser || process.versions.electron);

  var context =
    { exports:       {}
    , __dirname:     path.dirname(filename)
    , __filename:    filename
    , log:           logging.getLogger(path.basename(filename))
    , use:           requireWisp
    , process:       { cwd:    process.cwd
                     , stdin:  process.stdin
                     , stdout: process.stdout
                     , stderr: process.stderr
                     , exit:   process.exit
                     , argv:   process.argv }
    , setTimeout:    setTimeout
    , clearTimeout:  clearTimeout
    , setInterval:   setInterval
    , clearInterval: clearInterval
    , isInstanceOf:  function (type, obj) { return obj instanceof type }
    , isSame:        function (a, b) { return a === b }
    , require:       _require };

  [ wisp.ast
  , wisp.sequence
  , wisp.string
  , wisp.runtime ].map(importIntoContext.bind(null, context));

  if (elevated) {
    context.process = process;
    context.require = require;
  }

  if (browser) {
    console.log(global);
    context.document = document;
  }

  function _require (module) {
    try {
      module = resolve.sync(module,
        { extensions: [".js", ".wisp"]
        , basedir:    path.dirname(filename) });
    } catch (e) {
      // passthru for electron's extra standard libraries
      return require(module)
    };
    if (!browser && path.extname(module) === '.wisp') {
      return requireWisp(module)
    } else {
      return require(module)
    }
  };
  _require.main = require.main;

  return vm.createContext(context);
}

var cache = module.exports.cache = [];

function requireWisp (name, raw, elevated) {
  var basedir  = path.dirname(require('resolve/lib/caller.js')())
    , filename = resolve.sync(name, { extensions: [".wisp"], basedir: basedir })

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
