var runtime = require('../runtime.js')
  , engine  = runtime.requireWisp('../engine.wisp')
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

  it('is an object returned by engine.start', function () {
    expect(typeof e).toBe('object');
  })

  it('knows its root dir', function () {
    expect(e.root).toBe(path.resolve(root));
  })

  it('has a root notion directory', function () {
    expect(e.tree.type).toBe('NotionDirectory');
    expect(e.tree.path).toBe(path.resolve(root));
  })

});

describe('a notion', function () {

  it('knows its type', function () {
    var n1 = notion.makeNotion();
    expect(n1.type).toBe('Notion');
  });

  it('knows its path and correctly derives its name from it', function () {
    var n1 = notion.makeNotion('spec/sample/n1');
    expect(n1.path).toBe('spec/sample/n1');
    expect(n1.name).toBe('n1');
    var n121 = notion.makeNotion('spec/sample/d1/d12/n121');
    expect(n121.path).toBe('spec/sample/d1/d12/n121');
    expect(n121.name).toBe('n121');
  });

  it('can have an empty name', function () {
    var n = notion.makeNotion('');
    expect(n.name).toBe('');
    expect(n.path).toBe('');
  })

  it('has empty name and source if not specified', function () {
    var n = notion.makeNotion();
    expect(n.name).toBe('');
    expect(n.path).toBe('');
    expect(n.source).toBe('');
  })

  it('has source as specified', function () {
    var n = notion.makeNotion('spec/sample/n1', '');
    expect(n.source).toBe('');
    var n = notion.makeNotion('spec/sample/n1', 'NIICHAVO');
    expect(n.source).toBe('NIICHAVO');
  })

  it('automatically loads its source on request', function () {
    var n = notion.makeNotion('spec/sample/n1');
    expect(n.source).toBe(fs.readFileSync('spec/sample/n1', 'utf8'));
  })

  it('automatically compiles on request', function () {
    var n = notion.makeNotion('', '42');
    expect(n.compiled).toBeDefined();
    expect(n.compiled).not.toBeNull();
    expect(n.compiled.output).toBeDefined();
    expect(n.compiled.output.code).toBe(
      '42;\n//# sourceMappingURL=data:application/json;base64,' +
      'eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbIjw/Pz8+Il0sIm5hbWVzIjp' +
      'bXSwibWFwcGluZ3MiOiJBQUFBIiwic291cmNlc0NvbnRlbnQiOlsiNDIiXX0=\n');
  })

  it('automatically evaluates on request', function () {
    var n = notion.makeNotion('', '42');
    expect(n.value).toBe(42);
  })

})

describe('a notion directory', function () {

  var d;

  beforeEach(function () {
    d = tree.makeNotionDirectory(root);
  })

  it('is an object returned by tree.make-notion-directory', function () {
    expect(typeof d).toBe('object');
  })

  it('knows its type, name, and path', function () {
    expect(d.type).toBe('NotionDirectory');
    expect(d.name).toBe(path.basename(root));
    expect(d.path).toBe(path.resolve(root));
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

  it('recursively loads its contents', function () {
    compareNotionTree(d.notions, notionTree);
  })

})

describe('a notion tree', function () {

  var d;

  beforeEach(function () {
    d = tree.loadNotionDirectory(root);
  })

  it('for the root directory, __ is undefined', function (done) {
    d.then(function (state) {
      var t = notion.getTree(state);
      expect(t.__).toBeUndefined();
      done();
    })
  })

  it('for non-root directory, __ points to parent', function (done) {
    d.then(function (state) {
      var t1 = notion.getTree(state);
      var t2 = notion.getTree(state.notions['d1']);
      var t3 = notion.getTree(state.notions['d1'].notions['d12']);
      expect(s(t2.__)).toEqual(s(t1));
      expect(s(t3.__)).toEqual(s(t2));
      expect(s(t3.__.__)).toEqual(s(t1));
      done();
    })
  })

  it('for any directory, _ points to self', function (done) {
    d.then(function (state) {
      var t1 = notion.getTree(state);
      var t2 = notion.getTree(state.notions['d1']);
      var t3 = notion.getTree(state.notions['d1'].notions['d12']);
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
