ifdef GLES
GL_LIBS=-cclib -lEGL -cclib -lX11 -cclib -lGLES_CM
else
GL_LIBS=-cclib -lGL -cclib -lX11
endif

all: glop.cma
opt: glop.cmxa

NAME = glop

ML_SOURCES = glop_intf.ml glop_impl_common.ml glop_impl.ml

ifdef GLES
C_SOURCES += gles.c
ML_IMPL = glop_impl_gles.ml
else
C_SOURCES += gl.c
ML_IMPL = glop_impl_gl.ml
endif

glop_impl.ml: $(ML_IMPL)
	ln -s $< $@

REQUIRES = bigarray algen

include make.common

.PHONY: all install uninstall reinstall

libglop.a: $(C_SOURCES:.c=.o)
	$(AR) rcs $@ $^

$(NAME).cma: $(ML_OBJS) libglop.a
	$(OCAMLC)   -a -o $@ -package "$(REQUIRES)" -custom -linkpkg $(OCAMLFLAGS) $(ML_OBJS) -cclib -lglop $(GL_LIBS)

$(NAME).cmxa: $(ML_XOBJS) libglop.a
	$(OCAMLOPT) -a -o $@ -package "$(REQUIRES)" $(OCAMLOPTFLAGS) $(ML_XOBJS) -cclib -lglop $(GL_LIBS)

install: all
	if test -f $(NAME).cmxa ; then extra="$(NAME).cmxa $(NAME).a" ; fi ; \
	ocamlfind install $(NAME) *.cmi $(NAME).cma META $(NAME).ml cnt.ml libglop.a $$extra

uninstall:
	ocamlfind remove $(NAME)

reinstall: uninstall install

check: $(NAME).cma $(NAME).cmxa
	@make -C tests all opt
	@for t in tests/*.byte tests/*.opt ; do $$t ; done
	@echo Ok

clean-spec:
	@make -C tests clean

distclean:
	@rm -f glop_impl.ml

include .depend
