var runtime = require('./runtime.js')
  , path    = require('path');

module.exports =
  { runtime: runtime
  , notion:  runtime.requireWisp('./notion.wisp')
  , tree:    runtime.requireWisp('./tree.wisp')
  , util:    runtime.requireWisp('./util.wisp')
  , export:  _export };

function _export (_module, dir) {
  var rel  = path.join.bind(null, path.dirname(_module.id))
    , ndir = module.exports.tree.makeNotionDirectory(rel(dir));
  ndir.name = require(rel('package.json')).name;
  _module.exports = module.exports.notion.getTree(ndir);
  return _module.exports;
}
