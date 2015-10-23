module.exports =
  { compileSource: compileSource
  , makeContext:   makeContext };

var path    = require('path');

function compileSource (source, opts) {
  return source;
}

function makeContext (script) {

  var filename = script.path;

  var context =
    { exports:       {}
    , __dirname:     path.dirname(filename)
    , __filename:    filename
    , console:       console
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
    , require:       require('require-like')(filename) };

  return context;

}
