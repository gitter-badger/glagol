module.exports =
  { compileSource: compileSource
  , makeContext:   makeContext };

var fs      = require('fs')
  , path    = require('path')
  , resolve = require('resolve');

function compileSource (source, opts) {

  // find wisp relative to project directory rather than glagol install path
  var wisp = patchWisp(findWisp(opts.path));

  var forms = wisp.compiler.readForms(source, opts.filename).forms;

  var processed = wisp.compiler.analyzeForms(forms)
  if (processed.error) throw ERR_ANALYZER(opts.filename, processed.error)

  var options =
        { 'source-uri': opts.filename || "<???>"
        , 'source':     source }
    , output  =
        wisp.compiler.generate.bind(null, options).apply(null, processed.ast);
  if (output.error) throw ERR_COMPILER(opts.filename, output.error)

  return output.code;

}

function ERR_ANALYZER (filename, error) {
  return Error("Wisp analyzer error in " + filename + ": " + error);
}

function ERR_COMPILER (filename, error) {
  return Error("Wisp compiler error in " + filename + ": " + error);
}

function makeContext (script, opts) {

  var wisp = patchWisp(findWisp(opts.path));

  var isBrowserify = process.browser
    , isElectron   = Boolean(process.versions.electron)
    , isBrowser    = isBrowserify || isElectron;

  var context = require('./javascript.js').makeContext(script);

  [ wisp.ast
  , wisp.sequence
  , wisp.string
  , wisp.runtime ].map(importIntoContext.bind(null, context));

  context.isInstanceOf = function (type, obj) { return obj instanceof type }
  context.isSame       = function (a, b) { return a === b }

  if (isBrowser) {
    context.document = document;
  }

  return context;

  function importIntoContext (context, obj) {
    Object.keys(obj).map(function(k) { context[k] = obj[k] });
  }

}

function findWisp (scriptPath) {
  var scriptDir =
        path.dirname(scriptPath)
    , wispDir =
        path.dirname(resolve.sync('wisp', { basedir: scriptDir }))
    , requireWisp =
        function (x) { return require(path.join(wispDir, x)) }
    , wisp =
        { _path:    wispDir
        , ast:      requireWisp('ast.js')
        , compiler: requireWisp('compiler.js')
        , expander: requireWisp('expander.js')
        , runtime:  requireWisp('runtime.js')
        , sequence: requireWisp('sequence.js')
        , string:   requireWisp('string.js') };

  return wisp;
}

function patchWisp (wisp) {

  /* First thing we do before being asked to compile any Wisp yet,
     is install a few compiler hacks that I'd like to be available
     everywhere throughout the runtime environment and haven't yet
     beel cleanly implemented from Wisp.

     Some of these might constitute suggested future patches to
     the main [Wisp](https://github.com/Gozala/wisp) codebase. (TODO: check) */

  installMacros(wisp);
  patchWriter(wisp);
  return wisp;

}

function installMacros(wisp) {

  /* For example, we enable the arrow macro, which threads
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
  */

  wisp.expander.installMacro("->", getArrowMacro);

}

function getArrowMacro (wisp) {

  /* The following implementation of the arrow "native" macro is taken
     directly from [Wisp docs](https://github.com/Gozala/wisp/blob/master/Readme.md#another-macro-example)
     and rewritten into JavaScript using some of [Wisp's sequence functions](https://github.com/Gozala/wisp/blob/master/src/sequence.wisp),
     which are modeled after Clojure's and implement soft immutability simply --
     by avoiding to modify things in place. */

  return function arrowMacro () {
    var operations = Array.prototype.slice.call(arguments, 0);
    var s = wisp.sequence;
    return s.reduce(function (form, op) {
      return s.cons(s.first(op), s.cons(form, s.rest(op)))
    }, s.first(operations), s.rest(operations));
  }

};

function patchWriter (wisp) {

  /* Some writer monkeypatches.

     TODO add `(def-` as shorthand for `(def ^:private`

     TODO upstream PR:
     There's also a typo carried over from upstream: `originam-form` should
     instead be `original-form` in the originam code. */

  var _writer = require(path.join(wisp._path, 'backend/escodegen/writer.js'));
  enableNestedNamespaces(wisp, _writer);
  enableVarlessDefs(wisp, _writer);

}

function enableNestedNamespaces (wisp, _writer) {

  /* By default, Wisp translates `(foo/bar/baz)` (a namespaced function call,
     with the `/` being roughly equivalent to a JS `.`, only with nested
     namespaces -- something that neither Wisp nor IIRC Clojure support --
     to the nonsencical `foo.bar/baz`. The following patch makes it produce
     the more consistent result `foo.bar.baz`, which accidentally is perfect
     for implementing a file tree equivalent for each Script.

     This is how in a Script the identifier `../options/setting` is made to
     return the value of the script at the corresponding filesystem path,
     relative to the calling script. Note that only the language construct is
     available runtime-wide; the functionality is not available from non-Script
     code (basically any code that comes into being by being `require`d).

     Strangely enough it also seems to be a magic/more magic switch, since to
     the cursory inspection the function seems to be doing nothing, yet things
     seemed to break last time I messed with it. TODO: check */

  var _translate = _writer.translateIdentifierWord;
  _writer.translateIdentifierWord = function translateIdentifierWord_patched () {
    var id = _translate.apply(null, arguments);
    return id;
  }

}

function enableVarlessDefs (wisp, _writer) {

  /* And this gets rid of an unnecessary limitation in function declaration order.
     It changes the way Wisp compiles (fn foo [] :bar) top-level local functions:
     the `var ...` part in `var foo = function foo () { return "bar" }` is not
     really necessary, but when present it prevents local functions from seeing
     some things declared before and some things declared afterwars, as well as
     themselves, which makes recursion painful.

     A similar patch is likely needed for locals since, in the following code:
     `(let [foo (fn foo [] (foo))])`, `foo` cannot actually call itself.
     So you can see the following workaround in some places:
     `(let [foo nil] (set! foo (fn [] (foo))))`. TODO */

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

}
