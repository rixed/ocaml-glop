OCAMLPATH = ..

.PHONY: all clean clear install reinstall uninstall

NAME = glop

LIB_SOURCES = \
	glop_intf.ml glop_spec.ml matrix_impl.ml glop_base.ml glop_impl.ml \
	glop_view.ml

ifdef GLES
C_SOURCES += gles.c
ML_BASE = glop_spec_gles.ml
else
C_SOURCES += gl.c
ML_BASE = glop_spec_gl.ml
endif

ML_SOURCES = $(LIB_SOURCES)

INSTALL = \
	$(NAME).cmxa $(NAME).cma $(LIB_SOURCES:.ml=.cmi) $(LIB_SOURCES:.ml=.cmx) \
	glop.a libglop.a META

all: $(INSTALL)

byte: glop.cma
opt: glop.cmxa

include make.conf
make.conf:
	echo "#GLES=1" > $@

ifdef GLES
GL_LIBS=-ccopt "$(LDFLAGS)" -cclib -lEGL -cclib -lX11 -cclib -lGLES_CM
else
GL_LIBS=-ccopt "$(LDFLAGS)" -cclib -lGL -cclib -lX11
endif

glop_spec.ml: $(ML_BASE)
	ln -s $< $@

REQUIRES = bigarray algen

include make.common

.PHONY: all opt install uninstall reinstall

libglop.a: $(C_SOURCES:.c=.o)
	$(AR) rcs $@ $^

$(NAME).cma: $(ML_OBJS) libglop.a
	$(OCAMLC)   -a -o $@ -package "$(REQUIRES)" -custom $(OCAMLFLAGS) $(ML_OBJS) -cclib -lglop $(GL_LIBS)

$(NAME).cmxa: $(ML_XOBJS) libglop.a
	$(OCAMLOPT) -a -o $@ -package "$(REQUIRES)" $(OCAMLOPTFLAGS) $(ML_XOBJS) -cclib -lglop $(GL_LIBS)

install: $(INSTALL)
	ocamlfind install $(NAME) $^

uninstall:
	ocamlfind remove $(NAME)

reinstall: uninstall install

check: $(NAME).cmxa
	$(MAKE) -C tests all
	@for t in tests/*.opt ; do $$t ; done
	@echo Ok

clean-spec:
	$(MAKE) -C tests clean

distclean-spec:
	$(RM) glop_spec.ml make.conf

clear:
	find . -type f -\( -name '*.ml' -o -name '*.mli' -o -name '*.c' -o -name '*.h' -\) | xargs sed -i -e 's/[ \t]\+$$//'

-include .depend
