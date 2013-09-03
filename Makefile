DC ?= ldmd2


ifeq (64,$(MODEL))
  DC_FLAGS += -m64
else
  # DC_FLAGS += -m32
endif

# DC_OUT = $(shell $(DC) 2>/dev/null | head -1)
# ifneq (,$(findstring LDC,$(DC_OUT)))
#   $(info LDC detected: Appending -op and LARGEADDRESSAWARE flags)
#   # LDC, for some reason, doens't compile with large addresses in mind.
#   DC_FLAGS += -L"-LARGEADDRESSAWARE"
#   DEBUG_FLAGS += -op
#   UNITTEST_FLAGS += -op
# endif

RELEASE_FLAGS         += -O -release -noboundscheck -inline -g
SPEEDTEST_FLAGS       += $(RELEASE_FLAGS) -version=SpeedTest
DEBUG_FLAGS           += -debug -de -gc
UNITTEST_FLAGS        += -unittest -debug -g
UNITTEST_DISKIO_FLAGS += $(UNITTEST_FLAGS) -version=TestOnDiskPersistence

# Build the import directory string out of the given import directories
# (append -I to each directory)
SOURCE_FILES := $(shell ls src/**/*.d) \
  src/consts.d \
  src/delta_queue.d \
  src/haar.d \
  src/query.d \
  src/reserved_array.d \
  src/sig.d \
  src/types.d \
  src/util.d

SERVER_FILES = src/server.d
CLIENT_FILES = src/client.d

# VIBE_FILES = $(shell ls vendor/vibe.d/source/vibe/**/*.d)
# VIBE_OBJ   = vibed.o

VENDOR_INCLUDES = -Ivendor/vibe.d/source -Ivendor/openssl

SERVER_BIN = server
CLIENT_BIN = client
DUB_BIN    = vendor/dub/bin/dub
DUB_BUILD_SCRIPT = ./build.sh

ifeq ($(OS),Windows_NT)
  SERVER_BIN = server.exe
  CLIENT_BIN = client.exe
	DUB_BIN    = vendor/dub/bin/dub.exe
	DUB_BUILD_SCRIPT = cmd /c build.cmd
endif

ALL_BIN = $(SERVER_BIN) $(CLIENT_BIN)

.PHONY: all
all: debug

.PHONY: debug
debug: DC_FLAGS += $(DEBUG_FLAGS)
debug: $(ALL_BIN)

.PHONY: release
release: DC_FLAGS += $(RELEASE_FLAGS)
release: $(ALL_BIN)

.PHONY: unittest
unittest: DC_FLAGS += $(UNITTEST_FLAGS)
unittest: $(ALL_BIN)
	$(ALL_BIN)

.PHONY: unittest_diskio
unittest_diskio: DC_FLAGS += $(UNITTEST_DISKIO_FLAGS)
unittest_diskio: $(ALL_BIN)
	$(ALL_BIN)

.PHONY: speedtest
speedtest: DC_FLAGS += $(SPEEDTEST_FLAGS)
speedtest: $(ALL_BIN)

$(SERVER_BIN): $(VIBE_OBJ)
	$(DC) $(DC_FLAGS) $(SERVER_FILES) $(SOURCE_FILES) $(VIBE_OBJ) $(VENDOR_INCLUDES) -of$(SERVER_BIN)
	
$(CLIENT_BIN): $(VIBE_OBJ)
	$(DC) $(DC_FLAGS) $(CLIENT_FILES) $(SOURCE_FILES) $(VIBE_OBJ) $(VENDOR_INCLUDES) -of$(CLIENT_BIN)

$(VIBE_OBJ): $(DUB_BIN)
	$(DUB_BIN) --compiler=$(DC)

$(DUB_BIN):
	cd vendor/dub && \
	$(DUB_BUILD_SCRIPT)

.PHONY: clean
clean:
	rm -rf bin/*.*
	rm -rf *.obj
	rm -rf *.o
	rm -rf *.exe
