var runtime = require('../runtime.js')
  , engine  = runtime.requireWisp('../engine.wisp')
  , notion  = engine.notion
  , fs      = require('fs');

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
    expect(n.compiled.output.code).toBe(
      '42;\n//# sourceMappingURL=data:application/json;base64,' +
      'eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbIjw/Pz8+Il0sIm5hbWVzIjp' +
      'bXSwibWFwcGluZ3MiOiJBQUFBIiwic291cmNlc0NvbnRlbnQiOlsiNDIiXX0=\n');
  })

  it('automatically evaluates on request', function () {
    var n = notion.makeNotion('', '42');
    expect(n.value).toBe(42);
  })

  it('automatically recompiles and re-evaluates when its source is changed',
    function () {
      var n = notion.makeNotion('', '42');
      n.source = '23';
      expect(n.compiled.output.code).toBe( // TODO
        '23;\n//# sourceMappingURL=data:application/json;base64,' +
        'eyJ2ZXJzaW9uIjozLCJzb3VyY2VzIjpbIjw/Pz8+Il0sIm5hbWVzIjp' +
        'bXSwibWFwcGluZ3MiOiJBQUFBIiwic291cmNlc0NvbnRlbnQiOlsiMjMiXX0=\n');
      expect(n.value).toBe(23);
    });

})

