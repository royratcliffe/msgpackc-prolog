SOBJ = $(PACKSODIR)/msgpackc.$(SOEXT)
OBJ = c/msgpackc.o

CFLAGS += -O2 -fomit-frame-pointer

all: $(SOBJ)

# Add some special treatment for Windows, since it does not have a mkdir "-p" option.
# It will create the parent directories automatically if they do not already exist.
# However, it requires the use of backslashes instead of forward slashes in the path.
$(SOBJ): $(OBJ)
ifeq ($(OS),Windows_NT)
	mkdir $(subst /,\,$(PACKSODIR))
else
	mkdir -p $(PACKSODIR)
endif
	$(LD) $(LDSOFLAGS) -o $@ $(OBJ) $(SWISOLIB)

check::
install::
clean:
	rm -f $(OBJ)
distclean: clean
	rm -f $(SOBJ)
