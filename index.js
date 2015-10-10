var runtime = require('./runtime.js')
  , fs      = require('fs')
  , path    = require('path');

module.exports =
  { runtime: runtime
  , notion:  runtime.requireWisp('./notion.wisp')
  , tree:    runtime.requireWisp('./tree.wisp')
  , util:    runtime.requireWisp('./util.wisp')
  , export:  export_
  , start:   start };

function export_ (_module, dir) {
  var rel  = path.join.bind(null, path.dirname(_module.id))
    , ndir = module.exports.tree.makeNotionDirectory(rel(dir));
  ndir.name = require(rel('package.json')).name;
  _module.exports = module.exports.notion.getTree(ndir);
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
      , root = tree.makeNotionDirectory(path.dirname(arg1))
      , main = tree.descend(root, path.basename(arg1))
      , val  = main.value;

    return (typeof val === "function") ? val(root) : val;

  }
}
