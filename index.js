var runtime = require('./runtime.js');

module.exports =
  { runtime: runtime
  , notion:  runtime.requireWisp('./notion.wisp')
  , tree:    runtime.requireWisp('./tree.wisp')
  , util:    runtime.requireWisp('./util.wisp') };
