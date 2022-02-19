SOBJ = $(PACKSODIR)/msgpackc.$(SOEXT)
OBJ = c/msgpackc.o c/objectc.o c/unpack.o c/version.o c/vrefbuffer.o c/zone.o

CFLAGS += -Ih -O2 -fomit-frame-pointer

all: $(SOBJ)

$(SOBJ): $(OBJ)
	mkdir -p $(PACKSODIR)
	$(LD) $(LDSOFLAGS) -o $@ $(OBJ) $(SWISOLIB)

check::
install::
clean:
	rm -f $(OBJ)
distclean: clean
	rm -f $(SOBJ)
