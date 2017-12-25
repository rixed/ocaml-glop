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
	$(RM) $(PROGRAMS) $(PROGRAMS:.byte=.opt)

-include .depend
