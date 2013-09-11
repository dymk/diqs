DC ?= dmd

ifeq (64,$(MODEL))
  DC_FLAGS += -m64
else
  DC_FLAGS += -m32
endif

ifeq ($(OS),Windows_NT)
  EXE_EXT :=.exe
  ifneq (,$(findstring 2.063,$(shell $(DC) 2>/dev/null | head -1)))
  	$(info Compiler is DMD)
    OBJ_EXT :=.obj
  else
    $(info Compiler is NOT DMD)
    OBJ_EXT :=.o
  endif
else
  OBJ_EXT :=.o
  EXE_EXT :=
endif

RELEASE_FLAGS         += -O -release -noboundscheck -inline
SPEEDTEST_FLAGS       += $(RELEASE_FLAGS) -version=SpeedTest
DEBUG_FLAGS           += -debug -de -gc
UNITTEST_FLAGS        += -unittest
UNITTEST_DISKIO_FLAGS += $(UNITTEST_FLAGS) -version=TestOnDiskPersistence

SERVER_FILES = src/server.d
CLIENT_FILES = src/client.d

SERVER_OBJ = server$(OBJ_EXT)
CLIENT_OBJ = client$(OBJ_EXT)

SERVER_BIN = server$(EXE_EXT)
CLIENT_BIN = client$(EXE_EXT)

DIQS_DIR   := src
DIQS_OBJ   := diqs$(OBJ_EXT)
DIQS_FILES := \
  $(shell ls src/image_db/*.d) \
  $(shell ls src/magick_wand/*.d) \
  $(shell ls src/persistence_layer/*.d) \
  src/consts.d \
  src/delta_queue.d \
  src/haar.d \
  src/query.d \
  src/reserved_array.d \
  src/sig.d \
  src/types.d \
  src/util.d

MSGPACK_DIR   := vendor/msgpack-d/src
MSGPACK_OBJ   := msgpack$(OBJ_EXT)
MSGPACK_FILES := $(MSGPACK_DIR)/msgpack.d

PAYLOAD_FILES := $(shell ls src/net/*.d)
PAYLOAD_OBJ   := payload$(OBJ_EXT)

# ====================================================================
VIBE_DIR   := vendor/vibe-d/source
VIBE_OBJ := vibe-d$(OBJ_EXT)
VIBE_FILES := $(shell find \
  vendor/vibe-d/source/vibe/core \
  vendor/vibe-d/source/vibe/data \
  -name '*.d' -printf "%p ") \
  $(VIBE_DIR)/vibe/utils/hashmap.d \
  $(VIBE_DIR)/vibe/utils/memory.d \
  $(VIBE_DIR)/vibe/utils/array.d \
  $(VIBE_DIR)/vibe/utils/string.d \
  $(VIBE_DIR)/vibe/inet/path.d \
  $(VIBE_DIR)/vibe/inet/url.d \
  $(VIBE_DIR)/vibe/textfilter/urlencode.d \
  $(VIBE_DIR)/vibe/textfilter/html.d

ifeq ($(OS),Windows_NT)
  ifeq (64,$(MODEL))
    VIBE_LIBS := \
      $(VIBE_DIR)/../lib/win-amd64/libeay32.lib \
      $(VIBE_DIR)/../lib/win-amd64/ssleay32.lib
  else
    VIBE_LIBS := \
      $(VIBE_DIR)/../lib/win-i386/event2.lib \
      $(VIBE_DIR)/../lib/win-i386/eay.lib \
      $(VIBE_DIR)/../lib/win-i386/ssl.lib
  endif

  VIBE_VERSIONS := -version=VibeWin32Driver
  # OS_LIBS := wsock32.lib ws2_32.lib user32.lib
else
  VIBE_VERSIONS := -version=VibeLibeventDriver
  OS_LIBS := -levent -levent_pthreads -lssl -lcrypto
endif
# ====================================================================

# ====================================================================
OPENSSL_DIR  := vendor/openssl
LIBEVENT_DIR := vendor/libevent
# ====================================================================

INCLUDE_DIRS = -I$(VIBE_DIR) -I$(MSGPACK_DIR) -I$(DIQS_DIR)

VERSIONS = -version=VibeCustomMain $(VIBE_VERSIONS)
DC_FLAGS += $(VERSIONS) $(INCLUDE_DIRS)

ALL_BIN = $(SERVER_BIN) $(CLIENT_BIN)
# ALL_BIN = $(SERVER_BIN)

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

$(SERVER_BIN): $(SERVER_OBJ) $(VIBE_OBJ) $(DIQS_OBJ) $(MSGPACK_OBJ) $(PAYLOAD_OBJ)
	$(DC) $(DC_FLAGS) $(SERVER_OBJ) $(VIBE_OBJ) $(DIQS_OBJ) $(MSGPACK_OBJ) $(PAYLOAD_OBJ) $(VIBE_LIBS) -of$(SERVER_BIN)

$(SERVER_OBJ): $(SERVER_FILES)
	$(DC) $(INCLUDE_DIRS) $(SERVER_FILES)  -c -of$(SERVER_OBJ)

$(CLIENT_BIN): $(CLIENT_OBJ) $(VIBE_OBJ) $(DIQS_OBJ) $(MSGPACK_OBJ) $(PAYLOAD_OBJ)
	$(DC) $(DC_FLAGS) $(CLIENT_OBJ) $(VIBE_OBJ) $(DIQS_OBJ) $(MSGPACK_OBJ) $(PAYLOAD_OBJ) $(VIBE_LIBS) -of$(CLIENT_BIN)

$(CLIENT_OBJ): $(CLIENT_FILES)
	$(DC) $(INCLUDE_DIRS) $(CLIENT_FILES)  -c -of$(CLIENT_OBJ)

$(PAYLOAD_OBJ): $(PAYLOAD_FILES)
	$(DC) $(PAYLOAD_FILES) $(INCLUDE_DIRS) -c -of$(PAYLOAD_OBJ)

$(DIQS_OBJ): $(DIQS_FILES)
	$(DC) $(DC_FLAGS) $(DIQS_FILES)    -c -of$(DIQS_OBJ)

$(VIBE_OBJ): $(VIBE_FILES)
	$(DC) $(DC_FLAGS) $(VIBE_FILES)    -c -of$(VIBE_OBJ)

$(MSGPACK_OBJ): $(MSGPACK_FILES)
	$(DC) $(DC_FLAGS) $(MSGPACK_FILES) -c -of$(MSGPACK_OBJ)

.PHONY: clean
clean:
	rm -rf bin/*.*
	rm -rf *.obj
	rm -rf *.o
	rm -rf *.exe
