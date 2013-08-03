DC = ldmd2
FILES = $(shell ls src/**/*.d src/*.d)
INCLUDE = src
DIQS_BIN = bin/diqs

DC_FLAGS = -m64
DC_FLAGS += $(foreach dir,$(INCLUDE),-I$(dir))

RELEASE_FLAGS = -release -inline -O
DEBUG_FLAGS   = -debug -unittest -g -w -wi

.PHONY: all
all: debug

.PHONY: debug
debug: DC_FLAGS += $(DEBUG_FLAGS)
debug: $(DIQS_BIN)

.PHONY: release
release: DC_FLAGS += $(RELEASE_FLAGS)
release: $(DIQS_BIN)

.PHONY: unittest
unittest: debug
	$(DIQS_BIN)

$(DIQS_BIN):
	$(DC) $(FILES) $(DC_FLAGS) -of$(DIQS_BIN)

.PHONY: clean
clean:
	rm -rf bin/*
	rm -rf *.obj
	rm -rf *.exe
