include ../make.conf

REQUIRES = glop

PROGRAMS = open_close.opt colors.opt showroom.opt
all: $(PROGRAMS)

ML_SOURCES = open_close.ml colors.ml showroom.ml

include ../make.common

# Common rules
.cmx.opt:
	$(OCAMLOPT) -o $@ -package "$(REQUIRES)" -linkpkg $(OCAMLOPTFLAGS) $^

clean-spec:
	$(RM) *.cm[ioxa] *.cmxa *.a *.byte *.opt *.s *.o

distclean-spec:

-include .depend
