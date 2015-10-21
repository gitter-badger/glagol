var path = require('path')
  , fs   = require('fs');

var core    = require('..');

var ROOT         = './spec/sample'
  , NEW_FILE     = path.join(ROOT, 'new-script')
  , NEW_DIR      = path.join(ROOT, 'new-directory')
  , NEW_DIR_FILE = path.join(NEW_DIR, 'new-script-2');

describe('a script directory', function () {

  var d;

  beforeEach(function () {
    // if they already exist at load time (e.g. previous run didn't clean up),
    // delete those files and directories that will be created at runtime and
    // be used to check whether creating new scripts at runtime works
    if (fs.existsSync(NEW_FILE))     fs.unlinkSync(NEW_FILE);
    if (fs.existsSync(NEW_DIR_FILE)) fs.unlinkSync(NEW_DIR_FILE);
    if (fs.existsSync(NEW_DIR))      fs.rmdirSync(NEW_DIR);

    // create a fresh script dir instance in the root path
    d = core.Directory(ROOT);
  })

  it('is an object instantiated by core.Directory', function () {
    expect(typeof d).toBe('object');
  })

  it('knows its type, name, and path', function () {
    expect(d.type).toBe('Directory');
    expect(d.name).toBe(path.basename(ROOT));
    expect(d.path).toBe(path.resolve(ROOT));
  })

  function compareScriptTree (nodes, contents) {
    expect(Object.keys(nodes).length).toBe(Object.keys(contents).length);
    Object.keys(contents).map(function (x) {
      expect(nodes[x]).toBeDefined();
      if (nodes[x]) {
        if (x[0] === 'd') {
          expect(nodes[x].type).toBe('Directory');
          compareScriptTree(nodes[x].nodes, contents[x]);
        } else if (x[0] === 'n') expect(nodes[x].type).toBe('Script');
      }
    });
  }

  it('recursively loads its contents', function () {
    compareScriptTree(d.nodes,
      { d1: { d11: { n111: null }
            , d12: { n121: null, n122: null }
            , n11: null }
      , d2: { n21: null }
      , d3: {}
      , n1: null
      , n2: null });
  })

  it('sets a reference to itself in each contained object', function () {
    expect(Object.keys(d.nodes).every(hasParent)).toBe(true);
    function hasParent (n) { return d.nodes[n].parent === d };
  })

  it('creates a Script object for a newly created file', function (done) {

    // create a new file, then wait for the watcher to pick it up

    fs.writeFileSync(NEW_FILE, '42');

    var n = path.basename(NEW_FILE)
      , t = setInterval(check, 250);

    function check () {
      if (-1 < Object.keys(d.nodes).indexOf(n)) {
        clearInterval(t);
        expect(d.nodes[n].value).toBe('42');
        fs.unlinkSync(NEW_FILE);
        done();
      }
    }

  }, 10000);

  xit('creates a Directory object for a newly created directory', function (done) {

    // create a new directory, containing another file,
    // then wait for the watcher to pick them up

    fs.mkdirSync(NEW_DIR);
    fs.writeFileSync(NEW_DIR_FILE, '42');

    var nd = path.basename(NEW_DIR)
      , nf = path.basename(NEW_DIR_FILE)
      , t  = setInterval(check, 250);

    function check () {
      console.log("BAR", Object.keys(d.nodes));
      if (-1 < Object.keys(d.nodes).indexOf(nd)) {
        console.log(d.nodes[nd]);
        clearInterval(t);
        fs.unlinkSync(NEW_DIR_FILE);
        fs.rmdirSync(NEW_DIR);
        done();
      }
    }

  }, 10000);

})

