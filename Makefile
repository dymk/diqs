DC ?= dmd

ifeq (64,$(MODEL))
  DC_FLAGS += -m64
endif

ifeq ($(OS),Windows_NT)
  OBJ_EXT :=.obj
  EXE_EXT :=.exe
else
  OBJ_EXT :=.o
  EXE_EXT :=
endif

RELEASE_FLAGS         += -O -release -noboundscheck -inline
SPEEDTEST_FLAGS       += $(RELEASE_FLAGS) -version=SpeedTest
DEBUG_FLAGS           += -debug -de -gc
UNITTEST_FLAGS        += -unittest
UNITTEST_DISKIO_FLAGS += $(UNITTEST_FLAGS) -version=TestOnDiskPersistence

DC_VENDOR_FLAGS = -O -release -noboundscheck

# Include msgpack because it's only 1 file.
SOURCE_FILES := \
  $(shell ls src/**/*.d) \
  src/consts.d \
  src/delta_queue.d \
  src/haar.d \
  src/query.d \
  src/reserved_array.d \
  src/sig.d \
  src/types.d \
  src/util.d \
  vendor/msgpack-d/src/msgpack.d

SERVER_FILES = src/server.d
CLIENT_FILES = src/client.d

# ====================================================================
VIBE_DIR   := vendor/vibe-d/source
VIBE_FILES := $(shell find $(VIBE_DIR) -name "*.d" -type f -printf "%p ")
VIBE_OBJ   := vibe-d$(OBJ_EXT)

ifeq ($(OS),Windows_NT)
  ifeq (64,$(MODEL))
    VIBE_LIBS = \
      $(VIBE_DIR)/../lib/win-amd64/libeay32.lib \
      $(VIBE_DIR)/../lib/win-amd64/ssleay32.lib
  else
    VIBE_LIBS = \
      $(VIBE_DIR)/../lib/win-i386/event2.lib \
      $(VIBE_DIR)/../lib/win-i386/eay.lib \
      $(VIBE_DIR)/../lib/win-i386/ssl.lib
  endif

  OS_LIBS := wsock32.lib ws2_32.lib
else
  OS_LIBS := -levent -levent_pthreads -lssl -lcrypto
endif
# ====================================================================

# ====================================================================
OPENSSL_DIR = vendor/openssl
OPENSSL_FILES = \
  $(OPENSSL_DIR)/deimos/openssl/bio.d
OPENSSL_OBJ = openssl$(OBJ_EXT)
# ====================================================================

# ====================================================================
LIBEVENT_DIR = vendor/libevent
LIBEVENT_FILES = $(shell ls $(LIBEVENT_DIR)/deimos/**/*.d)
LIBEVENT_OBJ = libevent$(OBJ_EXT)
# ====================================================================

SERVER_BIN = server$(EXE_EXT)
CLIENT_BIN = client$(EXE_EXT)

VENDOR_INCLUDES = -I$(VIBE_DIR) -I$(OPENSSL_DIR) -I$(LIBEVENT_DIR) -Ivendor/msgpack-d/src
VENDOR_OBJS     = $(VIBE_OBJ) $(OPENSSL_OBJ) $(LIBEVENT_OBJ)
VENDOR_LIBS     = $(VIBE_LIBS) $(OS_LIBS)

VERSIONS = -version=VibeCustomMain -version=VibeLibeventDriver
DC_FLAGS += $(VERSIONS)
DC_VENDOR_FLAGS += $(VERSIONS)

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

$(SERVER_BIN): $(VENDOR_OBJS)
	$(DC) $(DC_FLAGS) $(SOURCE_FILES) $(SERVER_FILES) $(VENDOR_OBJS) $(VENDOR_INCLUDES) $(VENDOR_LIBS) -of$(SERVER_BIN)

$(CLIENT_BIN): $(VENDOR_OBJS)
	$(DC) $(DC_FLAGS) $(CLIENT_FILES) $(SOURCE_FILES) $(VENDOR_OBJS) $(VENDOR_INCLUDES) $(VENDOR_LIBS) -of$(CLIENT_BIN)

$(VIBE_OBJ): $(OPENSSL_OBJ) $(LIBEVENT_OBJ)
	$(DC) $(DC_VENDOR_FLAGS) $(VIBE_FILES) $(VENDOR_INCLUDES) $(OPENSSL_OBJ) $(LIBEVENT_OBJ) $(VENDOR_LIBS) -c -of$(VIBE_OBJ)

$(OPENSSL_OBJ):
	$(DC) $(DC_VENDOR_FLAGS) $(OPENSSL_FILES) -I$(OPENSSL_DIR) -c -of$(OPENSSL_OBJ)

$(LIBEVENT_OBJ):
	$(DC) $(DC_VENDOR_FLAGS) $(LIBEVENT_FILES) -I$(LIBEVENT_DIR) -c -of$(LIBEVENT_OBJ)

.PHONY: clean
clean:
	rm -rf bin/*.*
	rm -rf *.obj
	rm -rf *.o
	rm -rf *.exe
