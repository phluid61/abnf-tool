target=abnf
#libraries=
objects=abnf rules

CC=gcc
CFLAGS=-O2 -Wall -pedantic

#CFLAGS:=$(shell pkg-config --cflags $(libraries)) $(CFLAGS)
#LDLIBS:=$(shell pkg-config --libs $(libraries)) $(LDLIBS)

.PHONY: default run clean

default: $(target)

run: $(target)
	-./$<

$(target): $(foreach obj,$(objects),$(obj).o)
	$(LINK.o) $^ $(LDLIBS) -o $@

define OBJ_template =
clean::
	-rm $(1).o
endef
$(foreach obj,$(objects),$(eval $(call OBJ_template,$(obj))))

clean::
	-rm $(target)

