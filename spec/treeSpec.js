var runtime = require('../runtime.js')
  , engine  = runtime.requireWisp('../engine.wisp')
  , notion  = engine.notion
  , tree    = engine.tree;

var root = './spec/sample';

describe('a notion tree', function () {

  var d;

  beforeEach(function () {
    d = tree.makeNotionDirectory(root);
  })

  it('for the root directory, __ is undefined', function () {
    var t = notion.getTree(d);
    expect(t.__).toBeUndefined();
  })

  it('for non-root directory, __ points to parent', function () {
    var t1 = notion.getTree(d);
    var t2 = notion.getTree(d.notions['d1']);
    var t3 = notion.getTree(d.notions['d1'].notions['d12']);
    expect(s(t2.__)).toEqual(s(t1));
    expect(s(t3.__)).toEqual(s(t2));
    expect(s(t3.__.__)).toEqual(s(t1));
  })

  it('for any directory, _ points to self', function () {
    var t1 = notion.getTree(d);
    var t2 = notion.getTree(d.notions['d1']);
    var t3 = notion.getTree(d.notions['d1'].notions['d12']);
    expect(t1._).toBe(t1)
    expect(t2._).toBe(t2);
    expect(t3._).toBe(t3);
    expect(s(t2.__._)).toEqual(s(t1));
    expect(s(t3.__._)).toEqual(s(t2));
    expect(s(t3.__.__._)).toEqual(s(t1));
  })

  function s (x) { return JSON.stringify(Object.keys(x)) }

  var view_from_n121_ =
    { _:  { n121: "Notion"
          , n122: "Notion" }
    , __: { d11: { n111: "Notion" }
          , d12: "Dir"
          , _:   "Dir"
          , __:  { d1: { d11: "Dir"
                       , d12: "Dir"
                       , n11: "Notion" }
                 , d2: { n21: "Notion" }
                 , d3: { }
                 , n1: "Notion"
                 , n2: "Notion"
                 , _:  "Dir"
                 , __: null } } };

})

