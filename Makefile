bin=/usr/local/bin

build:
	ocamlbuild -use-ocamlfind src/ackdo.native

tests:
	ocamlbuild -use-ocamlfind tests/tests.native
	./tests.native

install:
	cp ackdo.native $(bin)/ackdo

uninstall:
	rm -f $(bin)/ackdo

opaminstall:
	cp ackdo.native `ocamlc -where`/ackdo

opamuninstall:
	rm -f ackdo.native `ocamlc -where`/ackdo

clean:
	ocamlbuild -clean

.PHONY: build tests install uninstall clean
