var fs      = require('fs')
  , path    = require('path');

module.exports =
  { Script:    require('./script.js')
  , Directory: require('./directory.js')
  , runtime:   require('../runtimes/wisp.js')
  , export:    export_
  , start:     start };

function export_ (_module, dir) {
  var rel = path.join.bind(null, path.dirname(_module.id))
    , dir = module.exports.Directory(rel(dir));
  dir.name = require(rel('package.json')).name;
  _module.exports = require('./tree.js')(dir);
  return _module.exports;
}

function start () {
  var arg1 = process.argv[2];

  if (!arg1) {

    var usage =
      [ "usage:"
      , "  etude <dir>"
      , "  etude <file>"
      , "  etude <dir> <file>" ];
    console.log(usage.join("\n"));

  } else {

    arg1 = path.resolve(arg1);

    if (!fs.existsSync(arg1)) {
      console.log("\"" + entryPath + "\"", "doesn't seem to exist.");
      process.exit();
    }

    process.argv = process.argv.slice(3);

    var tree = module.exports.tree
      , root = module.exports.Directory(path.dirname(arg1))
      , main = root.descend(path.basename(arg1))
      , val  = main.value;

    return (typeof val === "function") ? val(root) : val;

  }
}
