var runtime = require('..').runtime
  , tree    = require('..').tree
  , path    = require('path')
  , fs      = require('fs');

var ROOT         = './spec/sample'
  , NEW_FILE     = path.join(ROOT, 'new-notion')
  , NEW_DIR      = path.join(ROOT, 'new-directory')
  , NEW_DIR_FILE = path.join(NEW_DIR, 'new-notion-2');

describe('a notion directory', function () {

  var d

  beforeEach(function () {
    // if they already exist at load time (e.g. previous run didn't clean up),
    // delete those files and directories that will be created at runtime and
    // be used to check whether creating new notions at runtime works
    if (fs.existsSync(NEW_FILE))     fs.unlinkSync(NEW_FILE);
    if (fs.existsSync(NEW_DIR_FILE)) fs.unlinkSync(NEW_DIR_FILE);
    if (fs.existsSync(NEW_DIR))      fs.rmdirSync(NEW_DIR);

    // create a fresh notion dir instance in the root path
    d = tree.makeNotionDirectory(ROOT);
  })

  it('is an object returned by tree.make-notion-directory', function () {
    expect(typeof d).toBe('object');
  })

  it('knows its type, name, and path', function () {
    expect(d.type).toBe('NotionDirectory');
    expect(d.name).toBe(path.basename(ROOT));
    expect(d.path).toBe(path.resolve(ROOT));
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

  it('creates notion out of new file added', function (done) {

    // create a new file, then wait for the watcher to pick it up

    fs.writeFileSync(NEW_FILE, '42');

    var n = path.basename(NEW_FILE)
      , t = setInterval(check, 250);

    function check () {
      if (-1 < Object.keys(d.notions).indexOf(n)) {
        clearInterval(t);
        expect(d.notions[n].value).toBe(42);
        fs.unlinkSync(NEW_FILE);
        done();
      }
    }

  }, 10000);

  xit('creates notion directory out of new dir added', function (done) {

    // create a new directory, containing another file,
    // then wait for the watcher to pick them up

    fs.mkdirSync(NEW_DIR);
    fs.writeFileSync(NEW_DIR_FILE, '42');

    var nd = path.basename(NEW_DIR)
      , nf = path.basename(NEW_DIR_FILE)
      , t  = setInterval(check, 250);

    function check () {
      console.log("BAR", Object.keys(d.notions));
      if (-1 < Object.keys(d.notions).indexOf(nd)) {
        console.log(d.notions[nd]);
        clearInterval(t);
        fs.unlinkSync(NEW_DIR_FILE);
        fs.rmdirSync(NEW_DIR);
        done();
      }
    }

  }, 10000);

})

