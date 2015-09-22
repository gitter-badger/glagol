var runtime = require('..').runtime
  , tree    = require('..').tree
  , path    = require('path');

var root = './spec/sample';

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
    compareNotionTree(d.notions,
      { d1: { d11: { n111: null }
            , d12: { n121: null, n122: null }
            , n11: null }
      , d2: { n21: null }
      , d3: {}
      , n1: null
      , n2: null });
  })


  it('sets a reference to itself in each contained object', function () {
    expect(Object.keys(d.notions).every(hasParent)).toBe(true);
    function hasParent (n) { return d.notions[n].parent === d };
  })

})

