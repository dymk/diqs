DC ?= ldmd2

ifeq (64,$(MODEL))
  DC_FLAGS += -m64
else
  DC_FLAGS += -m32
endif

RELEASE_FLAGS  := # -release -O -noboundscheck
DEBUG_FLAGS    := -debug -de -unittest -g
UNITTEST_FLAGS := -unittest -g

# Detect the DMD version, because -inline causes problems in 2.063
ifneq (,$(findstring 2.063,$(shell $(DC) 2>/dev/null | head -1)))
  $(info -----------------------------------------------------------------------------------------)
  $(info DMD 2.063's -inline won't work in this application. It is highly suggested you use 2.064.)
  $(info -----------------------------------------------------------------------------------------)
else
  RELEASE_FLAGS += -inline
endif

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
