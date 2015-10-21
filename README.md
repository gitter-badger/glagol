# Glagol 1.0.0

Glagol is a Node.js framework. It enables you to build programs that can be
edited on the fly. It also lets you use preprocessors, such as [Wisp](https://github.com/Gozala/wisp),
or [CoffeeScript](http://coffeescript.org/), or [Babel](https://babeljs.io/),
directly, reloading source files on demand, so you don't have to set up a
complicated build system to compile them in advance.

## In a nutshell

```
sudo npm install -g wisp glagol
mkdir x
echo '"edit me"' > x/a
echo '1000' > x/b
echo '(function r () { log(_["a"], _["b"]); setTimeout(r, _["b"]) })()' > x/c
glagol x/c
```

Now go ahead and edit the files `a` and `b`, and watch as the output of `c`
changes. Behind the scenes, Glagol keeps track of changes to the source code,
and provides the updated values upon request.


## Documentation

* [Changelog](https://github.com/egasimus/etude-engine/blob/master/CHANGELOG.md)
* [Roadmap](https://github.com/egasimus/etude-engine/blob/master/doc/roadmap.md)
* [Example applications in various stages of incompleteness](https://github.com/egasimus/etude-engine/blob/master/doc/examples.md)


## License
* Released under [GNU GPL3](https://github.com/egasimus/etude-engine/blob/master/LICENSE)
