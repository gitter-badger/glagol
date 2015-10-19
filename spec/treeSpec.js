var path = require('path')
  , fs   = require('fs');

var core      = require('..')
  , Script    = core.Script
  , Directory = core.Directory
  , tree      = require('../core/tree.js');

var ROOT = './spec/sample';

describe('a value tree', function () {

  var d;

  beforeEach(function () {
    d = Directory(ROOT);
  })

  it('for the root directory has __ undefined', function () {
    var t = tree(d);
    expect(t.__).toBeUndefined();
  })

  it('for non-root director has, __ pointing to parent', function () {
    var t1 = tree(d);
    var t2 = tree(d.nodes['d1']);
    var t3 = tree(d.nodes['d1'].nodes['d12']);
    expect(s(t2.__)).toEqual(s(t1));
    expect(s(t3.__)).toEqual(s(t2));
    expect(s(t3.__.__)).toEqual(s(t1));
  })

  it('for any directory has _ pointing to self', function () {
    var t1 = tree(d);
    var t2 = tree(d.nodes['d1']);
    var t3 = tree(d.nodes['d1'].nodes['d12']);
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

