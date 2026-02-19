CC ?= gcc
CC_BIN := $(firstword $(CC))
CPPFLAGS ?=
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -pedantic
LDFLAGS ?=

TARGET := reverse
SRC := reverse.c

PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin

PKG_NAME ?= $(TARGET)
PKG_VERSION ?= 1.0.0
PKG_ARCH ?= $(shell dpkg --print-architecture 2>/dev/null || echo amd64)
PKG_MAINTAINER ?= Valeriy Sofin <valeriysofin@local>
PKG_DIR := build/$(PKG_NAME)_$(PKG_VERSION)_$(PKG_ARCH)
PKG_FILE := dist/$(PKG_NAME)_$(PKG_VERSION)_$(PKG_ARCH).deb

.PHONY: all clean run install deb check-toolchain

all: check-toolchain $(TARGET)

check-toolchain:
	@command -v "$(CC_BIN)" >/dev/null 2>&1 || { \
		echo "Error: compiler '$(CC_BIN)' not found. Install build-essential."; \
		exit 1; \
	}
	@printf '#include <stdio.h>\nint main(void){return 0;}\n' | \
	"$(CC)" -x c - -o /dev/null >/dev/null 2>&1 || { \
		echo "Error: C development headers/libraries are missing. Install libc6-dev."; \
		exit 1; \
	}

$(TARGET): $(SRC)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $<

run: all
	./$(TARGET)

install: $(TARGET)
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 0755 "$(TARGET)" "$(DESTDIR)$(BINDIR)/$(TARGET)"

deb: all
	@command -v apt >/dev/null 2>&1 || { \
		echo "Error: apt not found. Run this target on Debian/Ubuntu."; \
		exit 1; \
	}
	sudo apt update && sudo apt install -y build-essential dpkg-dev
	@command -v dpkg-deb >/dev/null 2>&1 || { \
		echo "Error: dpkg-deb not found. Build on Debian/Ubuntu and install dpkg-dev."; \
		exit 1; \
	}
	rm -rf "$(PKG_DIR)"
	install -d "$(PKG_DIR)/DEBIAN" "$(PKG_DIR)/usr/bin" "dist"
	install -m 0755 "$(TARGET)" "$(PKG_DIR)/usr/bin/$(TARGET)"
	@printf "Package: $(PKG_NAME)\nVersion: $(PKG_VERSION)\nSection: utils\nPriority: optional\nArchitecture: $(PKG_ARCH)\nDepends: libc6\nMaintainer: $(PKG_MAINTAINER)\nDescription: 7x7 matrix task executable\n Random 7x7 matrix analyzer that zeroes the matrix when counts match.\n" > "$(PKG_DIR)/DEBIAN/control"
	dpkg-deb --build --root-owner-group "$(PKG_DIR)" "$(PKG_FILE)"
	@echo "Created $(PKG_FILE)"
	sudo apt install "./$(PKG_FILE)"

clean:
	rm -f "$(TARGET)"
	rm -rf "build" "dist"
