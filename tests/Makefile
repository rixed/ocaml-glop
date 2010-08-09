OCAMLPATH = ../..

REQUIRES = glop

PROGRAMS = open_close.byte colors.byte
all: $(PROGRAMS)
opt: $(PROGRAMS:.byte=.opt)

ML_SOURCES = open_close.ml

include ../make.common

# Common rules
.SUFFIXES: .ml .mli .cmo .cmi .cmx .opt .byte

.cmo.byte:
	$(OCAMLC)   -o $@ -package "$(REQUIRES)" -linkpkg $(OCAMLFLAGS) $^

.cmx.opt:
	$(OCAMLOPT) -o $@ -package "$(REQUIRES)" -linkpkg $(OCAMLOPTFLAGS) $^

include .depend
