build:
	ocamlbuild -use-ocamlfind src/ackdo.native

tests:
	ocamlbuild -use-ocamlfind tests/tests.native
	./tests.native

install:
	echo "install"

uninstall:
	echo "uninstall"

clean:
	ocamlbuild -clean

.PHONY: build tests install uninstall clean all
