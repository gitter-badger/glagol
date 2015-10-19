# Examples (in various stages of incompleteness)

In order to check out the **_really_ cool things** that Etude can leverage other
software to do by being **_so_ damn in tune with the spirit of Unix philosophy,**
you should have a look at one of the example projects:

* [etude-demo](https://github.com/egasimus/etude-demo) is where most of the
  development is brewing, including the current `terminal UI` fad. At an earlier
  stage it was capable of rendering a basic audio volume meter using
  [jackmeter](https://github.com/egasimus/jackmeter), before falling victim to
  refactoring.

* etude-demo is currently in the process of absorbing the code from
  [etude-project](https://github.com/egasimus/etude-project), which is a bit
  outdated to start with (was written before most of etude-engine took form)
  and further relies on its contemporary browserify-based bundler in
  [etude-web](https://github.com/egasimus/etude-web) - which is most likely
  groken. The HTML5 UI was built up to the point where it was capable of picking
  samples from a directory, telling the server part to launch a [postmelodic](https://github.com/egasimus/postmelodic)
  instance for each new sample, and triggering the playback of each via the
  keyboard, all from the convenience of a web browser.

* [etude-bless](https://github.com/egasimus/etude-bless) is the
  [vdom](https://github.com/Matt-Esch/virtual-dom)-inspired UI framework for
  etude-demo. Lets you render a GUI built out of [Unicode block elements](https://en.wikipedia.org/wiki/Block_Elements),
  by implementing a [declarative interface](https://github.com/egasimus/etude-bless)
  over the strongly imperative widgets of the underlying
  [blessed](https://github.com/egasimus/chjj/blessed).

* [etude-tmux](https://github.com/egasimus/etude-tmux) is a minimal attempt at
  producing a working single-purpose library that is built through `etude-engine`
  machinery. Currently it contains a basic implementation of a tmux layout
  string parser (you know, these things: `227x62,0,0{113x62,0,0,13,113x62,114,0,14}` )
  which has not yet been translated to Wisp from the original JS prototype.
  I need this so I can open new panes at the edges of my tmux session,
  regardless of the current session layout.

