##
# pacaur.sh - An AUR helper that minimizes user interaction
# port from unmaintained github.com/rmarquis/pacaur
##

PREFIX ?= /usr/local
bindir        = $(PREFIX)/bin
libdir        = $(PREFIX)/lib

# default target
# all: doc

# aux
install:
	@echo "Installing..."
	# Scripts
	@install -D -m755 ./pac-aur.bash $(DESTDIR)$(bindir)/pac-aur.bash
	# Libs
	@mkdir -p $(DESTDIR)$(libdir)/pac-aur/bash/operations
	@install -D -m644 bash/*.bash $(DESTDIR)$(libdir)/pac-aur/bash
	@install -D -m644 bash/operations/*.bash $(DESTDIR)$(libdir)/pac-aur/bash/operations/

uninstall:
	@echo "Uninstalling..."
	# Scripts
	@rm $(DESTDIR)$(bindir)/pac-aur.bash
	# Libs
	@rm $(DESTDIR)$(libdir)/pac-aur/bash/operations/*
	@rmdir $(DESTDIR)$(libdir)/pac-aur/bash/operations
	@rm $(DESTDIR)$(libdir)/pac-aur/bash/*
	@rmdir $(DESTDIR)$(libdir)/pac-aur/bash
	@rm -r $(DESTDIR)$(libdir)/pac-aur

clean:
	@echo "Cleaning..."

.PHONY: install uninstall clean
