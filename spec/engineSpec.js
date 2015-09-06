var runtime = require('../runtime.js')
  , engine  = runtime.requireWisp('../engine.wisp')
  , tree    = runtime.requireWisp('../tree.wisp')
  , path    = require('path');

var root = './spec/sample';

describe('an engine', function () {

  var e;
  beforeEach(function () { e = engine.start(root); })

  it('is promised by engine.start', function () {
    expect(e.then).toBeDefined();
  })

  it('knows its root dir', function (done) {
    e.then(function (state) {
      expect(state.root).toBe(path.resolve(root));
      done();
    })
  })

  it('has a root notion directory', function (done) {
    e.then(function (state) {
      expect(state.tree.type).toBe('NotionDirectory');
      expect(state.tree.path).toBe(path.resolve(root));
      done();
    })
  })

});

describe('a notion directory', function () {

  var d;
  beforeEach(function () { d = tree.loadNotionDirectory(root); })

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
      compareNotionTree(state.notions,
        { d1: { d11: { n3: null }, d12: { n4: null }, n11: null }
        , d2: { n21: null }
        , d3: {}
        , n1: null
        , n2: null });
      done();
    })
  })

})
