# Etude

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

In order to check out the **_really_ cool things** that Etude can leverage other
software to do by being **_so_ damn in tune with the spirit of Unix philosophy,**
you should have a look at one of the example projects that I'm also cooking up
for you. 

All that said, **please stay tuned!** Etude is a work in progress. A 0.1.0
release is now just about imminent. It would still suffer from the current lack
of sensible error messaging, and half of the time an exception occurs you would
be given way too little information, but it would otherwise still do its thing
ust fine. I'm kind of racing against my patience here since I don't have nearly
enough manhours on hand and I want to see it doing real world stuff that I would
know it is not a pipe dream which is why I alternate between that and
all the finicky infrastructural things such as getting source maps to work.
Another set of eyeballs would sure help. So brave traveller, if you happen to be
brave enough to poke around the code here and there, lemme hear about it!
