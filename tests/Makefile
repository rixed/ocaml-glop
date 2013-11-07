REQUIRES = glop

PROGRAMS = open_close.byte colors.byte showroom.byte
all: $(PROGRAMS)
opt: $(PROGRAMS:.byte=.opt)

ML_SOURCES = open_close.ml colors.ml showroom.ml

include ../make.common

# Common rules
.cmo.byte:
	$(OCAMLC)   -o $@ -package "$(REQUIRES)" -linkpkg $(OCAMLFLAGS) $^

.cmx.opt:
	$(OCAMLOPT) -o $@ -package "$(REQUIRES)" -linkpkg $(OCAMLOPTFLAGS) $^

clean-spec:
	@rm -f $(PROGRAMS) $(PROGRAMS:.byte=.opt)

-include .depend
