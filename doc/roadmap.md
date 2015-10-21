# Roadmap

* Unify `Script` and `Directory` classes -- dirs are just another file type.
* Extend beyond Wisp -- allow for vanilla JS as well as non-JS file types
* Replace Jasmine's built-in test runner with a dogfooded one
* Write detailed documentation for the available classes

## Known embarrasing issues

* Error messages are much less clear than they could be; server-side source maps
  are yet to be implemented, and compile errors after runtime updates aren't
  thrown -- instead the failed script's value gets set to `undefined`, which
  causes an exception further down the road.
* New directories still can't be created during runtime (files ok though)
