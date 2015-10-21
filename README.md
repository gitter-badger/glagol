# Glagol 1.0.0

Glagol is a Node.js framework. It enables you to build programs that can be
edited on the fly. It also lets you use preprocessors, such as [Wisp](https://github.com/Gozala/wisp),
or [CoffeeScript](http://coffeescript.org/), or [Babel](https://babeljs.io/),
directly, reloading source files on demand, so you don't have to set up a
complicated build system to compile them in advance.

## In a nutshell

```
sudo npm install -g glagol
mkdir x
echo '"edit me"' > x/a
echo '1000' > x/b
echo '(function r () { console.log(_["a"], _["b"]); setTimeout(r, _["b"]) })()' > x/c
glagol x/c
```

Now go ahead and edit the files `a` and `b`, and watch as the output of `c`
changes. Behind the scenes, Glagol keeps track of changes to the source code,
and, upon request, synchronously evaluates the current contents of a file and
returns the up-to-date value via the global `_` and `__` objects (which
correspond to the current and parent directories relative to the current file).

The set of globals available in each file's context is artificially reduced.
APIs for specifying those globals, for using other
sandboxing libraries, such as [contextify](https://github.com/brianmcd/contextify),
[localify](https://github.com/edge/localify), or [sandboxed-module](https://github.com/felixge/node-sandboxed-module),
and for applying arbitrary pre-and post-processing at the source and AST levels,
will be made available in due time.


## Documentation

* [Changelog](https://github.com/egasimus/glagol/blob/master/CHANGELOG.md)
* [Roadmap](https://github.com/egasimus/glagol/blob/master/doc/roadmap.md)
* [License (GPL3)](https://github.com/egasimus/glagol/blob/master/LICENSE)
