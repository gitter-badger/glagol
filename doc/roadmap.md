# Roadmap

* Re-enable [Wisp](https://github.com/Gozala/wisp) support ASAP, and
  write a couple more "runtime" (inaccurate name?) adapters for good measure
* Unify `Script` and `Directory` classes -- process dirs as just another file type
* Replace Jasmine's built-in test runner with a dogfooded one
* Write detailed documentation for the available classes

## Known embarrasing issues

* Error messages are much less clear than they could be; server-side source maps
  are yet to be implemented, and compile errors after runtime updates aren't
  thrown -- instead the failed script's value gets set to `undefined`, which
  causes an exception further down the road. (This mostly applies to Wisp though)
* New directories still can't be created during runtime (files are ok though)
