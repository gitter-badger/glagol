var runtime = require('../runtime.js')
  , engine  = runtime.requireWisp('../engine.wisp')
  , compile = engine.compile
  , tree    = engine.tree
  , notion  = engine.notion
  , fs      = require('fs')
  , path    = require('path');

var root = './spec/sample';
var notionTree =
  { d1: { d11: { n111: null }
        , d12: { n121: null, n122: null }
        , n11: null }
  , d2: { n21: null }
  , d3: {}
  , n1: null
  , n2: null }

describe('an engine', function () {

  var e;

  beforeEach(function () {
    e = engine.start(root);
  })

  it('is promised by engine.start', function () {
    expect(e.then).toBeDefined();
  })

  it('knows its root dir', function (done) {
    e.then(function (state) {
      expect(state.root).toBe(path.resolve(root));
      done();
    }).done();
  })

  it('has a root notion directory', function (done) {
    e.then(function (state) {
      expect(state.tree.type).toBe('NotionDirectory');
      expect(state.tree.path).toBe(path.resolve(root));
      done();
    })
  })

});

describe('a notion', function () {

  it('knows its type', function () {
    var n = notion.makeNotion('foo/bar-baz');
    expect(n.type).toBe('Notion');
  });

  it('knows its path and derives its name from it', function () {
    var n = notion.makeNotion('foo/bar-baz');
    expect(n.path).toBe('foo/bar-baz');
    expect(n.name).toBe('bar-baz');
  });

  it('can have an empty name', function () {
    var n = notion.makeNotion('');
    expect(n.name).toBe('');
    expect(n.path).toBe('');
  })

  it('has an empty name and source if not specified', function () {
    var n = notion.makeNotion();
    expect(n.name).toBe('');
    expect(n.path).toBe('');
    expect(n.source).toBe('');
  })

  it('has empty source if not specified', function () {
    var n = notion.makeNotion('foo/bar-baz');
    expect(n.source).toBe('');
  })

  it('has source as specified', function () {
    var n = notion.makeNotion('foo/bar-baz', '42');
    expect(n.source).toBe('42');
  })

  it('automatically loads its source on request', function () {
    var n = notion.makeNotion('spec/sample/n1');
    expect(n.source).toBe(fs.readFileSync('spec/sample/n1', 'utf8'));
  })

  it('automatically compiles on request', function () {
    var n = notion.makeNotion('', '42');
    expect(n.compiled.output.code).toBe([]);
  })

  it('automatically evaluates on request', function () {
    var n = notion.makeNotion('', '42');
    expect(n.compiled.output.code).toBe(42);
  })

})

describe('a notion directory', function () {

  var d;

  beforeEach(function () {
    d = tree.loadNotionDirectory(root);
  })

  it('is promised by tree.load-notion-directory', function () {
    expect(d.then).toBeDefined();
  })

  it('knows its type, name, and path', function (done) {
    d.then(function (state) {
      expect(state.type).toBe('NotionDirectory');
      expect(state.name).toBe(path.basename(root));
      expect(state.path).toBe(path.resolve(root));
      done();
    })
  })

  function compareNotionTree (notions, contents) {
    expect(Object.keys(notions).length).toBe(Object.keys(contents).length);
    Object.keys(contents).map(function (x) {
      expect(notions[x]).toBeDefined();
      if (notions[x]) {
        if (x[0] === 'd') {
          expect(notions[x].type).toBe('NotionDirectory');
          compareNotionTree(notions[x].notions, contents[x]);
        } else if (x[0] === 'n') expect(notions[x].type).toBe('Notion');
      }
    });
  }

  it('recursively loads its contents', function (done) {
    d.then(function (state) {
      compareNotionTree(state.notions, notionTree);
      done();
    })
  })

})

describe('a notion tree', function () {

  var d;

  beforeEach(function () {
    d = tree.loadNotionDirectory(root);
  })

  it('for the root directory, __ is undefined', function (done) {
    d.then(function (state) {
      var t = compile.getNotionTree(state);
      expect(t.__).toBeUndefined();
      done();
    })
  })

  it('for non-root directory, __ points to parent', function (done) {
    d.then(function (state) {
      var t1 = compile.getNotionTree(state);
      var t2 = compile.getNotionTree(state.notions['d1']);
      var t3 = compile.getNotionTree(state.notions['d1'].notions['d12']);
      expect(s(t2.__)).toEqual(s(t1));
      expect(s(t3.__)).toEqual(s(t2));
      expect(s(t3.__.__)).toEqual(s(t1));
      done();
    })
  })

  it('for any directory, _ points to self', function (done) {
    d.then(function (state) {
      var t1 = compile.getNotionTree(state);
      var t2 = compile.getNotionTree(state.notions['d1']);
      var t3 = compile.getNotionTree(state.notions['d1'].notions['d12']);
      expect(t1._).toBe(t1)
      expect(t2._).toBe(t2);
      expect(t3._).toBe(t3);
      expect(s(t2.__._)).toEqual(s(t1));
      expect(s(t3.__._)).toEqual(s(t2));
      expect(s(t3.__.__._)).toEqual(s(t1));
      done();
    })
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
