# Etude Engine

you come to a bottomless pit. dare you [peek inside](./index.js)?

## v0.2.0

### Known embarrasing issues:

* error messages are much less clear than they could be
* a notion created during runtime is not registered (no listener is currently
  being bound to chokidar's `added` event)
* saving a notion created during runtime twice causes crash (because there is
  still a listener for `changed`)
* you need to be in the correct directory to start a launcher script.

## Examples

In order to check out the **_really_ cool things** that Etude can leverage other
software to do by being **_so_ damn in tune with the spirit of Unix philosophy,**
you should have a look at one of the example projects:

* [etude-demo](../etude-demo) is where most of the development is brewing,
  including the current `terminal UI` fad. At an earlier stage it was capable
  of rendering a basic audio volume meter using [jackmeter](../jackmeter).

* [etude-bless](../etude-bless) is the [vdom](../../Matt-Esch/virtual-dom)-inspired
  UI framework for etude-demo. Lets you render a GUI built out of
  [Unicode block elements](https://en.wikipedia.org/wiki/Block_Elements),
  by implementing a [declarative interface](../etude-bless) over the strongly
  imperative widgets of the underlying [blessed](../../chjj/blessed) library.

* [etude-project](../etude-project) is a bit outdated. It relies on the bundler
  `etude-web` which is most likely groken. It was capable of loading samples
  from a directory, launching a [postmelodic](../postmelodic) instance for each,
  and playing them, all from a HTML5 UI you open in your web browser.

* [etude-tmux](../etude-tmux) is a minimal attempt at producing a working
  single-purpose library that is built through etude-engine's machinery.
  Currently it contains a basic implementation of a tmux layout string parser
  (you know, these things: `227x62,0,0{113x62,0,0,13,113x62,114,0,14}`).

## Description (wall of text warning)

**Etude is a framework for live coding of interactive applications**,
aiming to become a building block for highly modular, natively scriptable
and runtime-modifiable distributed software, such as needed for e.g. real-time
multimedia composition and performance. Etude is meant to be light enough to be
usable for real-time asynchronous single-purpose shell scripting, portable
enough to run a single-page Web application, yet flexible enough to fit
around the high-level parts of a digital audio workstation, because those
things are what I'll be using it for.

**Etude implements a lightweight nanoservice architecture.**
Etude's fundamental building block is called a [Notion](./spec/notionSpec.js).
Each notion directly corresponds to a file in your application's source code
tree; having read its source from disk, a Notion goes on to preprocess it,
evaluates it, and export the resulting value as a public API endpoint,
accessible from neighbouring notions via a familiar path-like syntax. Whenever
the file contents change, the notion is reloaded, and upon next request the
updated value is returned.

**Currently, notions can be written in [Wisp](https://github.com/Gozala/wisp)**,
a self-sufficient little language with syntax similar to Clojure's. Support for
vanilla JS or mainstream preprocessors such as CoffeeScript should be trivial
and should probably arrive around the time I need it enough to give up on the
current plain, extension-less look of the files. Each notion executes in a
dedicated somewhat isolated context (Node.js `vm`, browser `iframe`) within a
single JS VM instance (i.e. Node.js process, or a browser tab). An (upcoming)
language- and platform-agnostic VFS-based API intends to make distributed Etude
instances work seamlessly with each other by efficient use of a variety of
current-generation protocols such as file IO, HTTP, WebSockets, UDP, 9P, OSC, MIDI;
and existing JavaScript support for these protocols allows Etude to talk to the
whole wide world of non-Etude programs that implement them.

**A notion can export any value** - from a simple primitive such as the value of
a single configuration setting, to an object of functions that implement a
mini-library. The non-restrictive uniformity of code organized by putting one
logically discrete unit of code into each file (rather than grouping multiple
marginally related declarations into a few large files as is customary in most
platforms' module systems) brings unprecedented visibility of the basic application
structure without complex tooling (such as a language-specific IDE, though there
is one in the works anyway) and reduces the likelihood of circular references.

**Most importantly, having one thing per file** makes it trivial for Etude to know
when you change anything in the source code. Then it does its best to update the
running program on the fly. To help it do that, you need to stick to a
functional programming mindset: think of your program's control flow as a series
of data transforms rather than a sequence of imperative instructions, minimize
and centralize side effects, and aim to write as much pure and/or idempotent
code as possible; in return, you get truly hassle-free rapid application development.

Etude is even (going to be) able to do this in reverse, and **automatically
rewrite source code files** in response to changes to the application state; thus
blurring the line between code and data, any software built with Etude gets an
powerful scripting and debugging system at the cost of no extra effort. For example,
users of a multimedia package, or other domain-specific software, would now be able
to implement arbitrarily complex instructions in their projects, disregarding the
restrictions of any pre-defined GUI, and end up with text-based project files that
can be version-controlled and human-reviwed, unlike the binary files of most current-
generation multimedia software.

## Thanks for your attention!

As they said in the olden days when people had whole attention _spans_,
### _please stay tuned!_
