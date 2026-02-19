CC ?= gcc
CC_BIN := $(firstword $(CC))
CPPFLAGS ?=
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -pedantic
LDFLAGS ?=

TARGET := reverse
SRC := reverse.c

PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin

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

deb:
	@command -v dpkg-buildpackage >/dev/null 2>&1 || { \
		echo "Error: dpkg-buildpackage not found. Install dpkg-dev, debhelper, devscripts."; \
		exit 1; \
	}
	dpkg-buildpackage -us -uc -b

clean:
	rm -f "$(TARGET)"
