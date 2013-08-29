DC ?= ldmd2 -v

DC_OUT = $(shell $(DC) 2>/dev/null | head -1)

ifeq (64,$(MODEL))
  DC_FLAGS += -m64
else
  DC_FLAGS += -m32
endif

# ifneq (,$(findstring LDC,$(DC_OUT)))
#   $(info LDC detected: Appending -op and LARGEADDRESSAWARE flags)
#   # LDC, for some reason, doens't compile with large addresses in mind.
#   DC_FLAGS += -L"-LARGEADDRESSAWARE"
#   DEBUG_FLAGS += -op
#   UNITTEST_FLAGS += -op
# endif

RELEASE_FLAGS  += -O -release -noboundscheck -inline
DEBUG_FLAGS    += -debug -de -g
UNITTEST_FLAGS += -unittest -debug -g

# Build the import directory string out of the given import directories
# (append -I to each directory)
SOURCE_FILES := $(shell ls src/*.d src/**/*.d)
DIQS_BIN ?= diqs.exe

.PHONY: all
all: debug

.PHONY: debug
debug: DC_FLAGS += $(DEBUG_FLAGS)
debug: $(DIQS_BIN)

.PHONY: release
release: DC_FLAGS += $(RELEASE_FLAGS)
release: $(DIQS_BIN)

.PHONY: unittest
unittest: DC_FLAGS += $(UNITTEST_FLAGS)
unittest: $(DIQS_BIN)
	$(DIQS_BIN)

$(DIQS_BIN):
	$(DC) $(DC_FLAGS) $(SOURCE_FILES) -of$(DIQS_BIN)

.PHONY: clean
clean:
	rm -rf bin/*.*
	rm -rf *.obj
	rm -rf *.o
	rm -rf *.exe
