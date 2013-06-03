# ackdo-reloaded

ackdo is a companion to ack that allows you to preview changes made with
sed (or a similar tool) to ack's (or grep's) direct output.

Why reloaded?
The old version is still available but it was getting a littly hairy to
maintain and the source was small enough for me to simply rewrite it.  Also
I've changed my phiilosophy regarding dependencies for ackdo since core made
the code much cleaner. You're welcome to use the old version if you dislike
the extra dependencies it is functionally equivalent for now.

### Installing

Ackdo depends on the following:
```
core
sexplib
textutils
```
Which can all be easily installed through OPAM

To install simply run the following:
```
$ make
$ sudo make install
```

### Usage

Say you want to rename a function foo_bar to fooBar.
To preview changes:
```
$ ack -w 'foo_bar' | sed 's/foo_bar/fooBar/' | ackdo 
```
If you are happy with these changes you can write them with:
```
$ ack -w 'foo_bar' | sed 's/foo_bar/fooBar/' | ackdo -d
```

TODO : document everything else

### Disclaimer

Use at your own peril. Ackdo comes with absolutely no warranty.


### TODO

- create patch files
- colored diff of lines
- support more formatting options
- cleaner error handling

### License

MIT
