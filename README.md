# Etude Engine

you come to a bottomless pit. dare you [peek inside](https://github.com/egasimus/etude-engine/blob/master/index.js)?

## v0.4.0

### Known embarrasing issues:

* error messages are much less clear than they could be; server-side source maps
  are yet to be implemented, and compile errors after runtime updates aren't
  thrown -- instead the failed script's value gets set to `undefined`, which
  causes an exception further down the road.
* new directories still can't be created during runtime (files ok though)

## In a nutshell

```
sudo npm install -g wisp etude-engine
mkdir x
echo '"edit me"' > x/a
echo '100' > x/b
echo '(let [r nil] (set! r (fn [] (log ./a ./b) (set-timeout r ./b))) (r))' > x/c
etude x/c
```

## See also

* [The design of Etude](https://github.com/egasimus/etude-engine/blob/master/doc/design.md)
* [Example applications in various stages of incompleteness](https://github.com/egasimus/etude-engine/blob/master/doc/examples.md)


