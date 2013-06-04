bin=/usr/local/bin

PREFIX ?= $(shell dirname $(shell dirname `ocamlc -where`))

BINDIR ?= $(PREFIX)/bin

build:
	ocamlbuild -use-ocamlfind src/ackdo.native

tests:
	ocamlbuild -use-ocamlfind tests/tests.native
	./tests.native

install:
	cp ackdo.native $(bin)/ackdo

uninstall:
	rm -f $(BINDIR)/ackdo

opaminstall:
	cp ackdo.native $(BINDIR)/ackdo

opamuninstall:
	rm -f ackdo.native $(BINDIR)/ackdo

clean:
	ocamlbuild -clean

.PHONY: build tests install uninstall clean
