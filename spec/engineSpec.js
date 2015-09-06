var runtime = require('../runtime.js')
  , engine  = runtime.requireWisp('../engine.wisp')
  , tree    = runtime.requireWisp('../tree.wisp')
  , path    = require('path');

var root = './sample';

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
      expect(state.path).toBe(root);
      done();
    })
  })

  //it('recursively loads its contents as notions', function (done) {
    //d.then(function (state) {
      //console.log(state.notions);
      //done();
    //})
  //})

})
