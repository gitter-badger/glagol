var runtime = require('../runtime.js')
  , engine  = runtime.requireWisp('../engine.wisp')
  , notion  = engine.notion
  , path    = require('path');

var root = './spec/sample';

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

