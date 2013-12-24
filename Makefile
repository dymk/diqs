DC ?= dmd

ifeq (64,$(MODEL))
  DC_FLAGS += -m64
endif

ifeq ($(OS),Windows_NT)
  EXE_EXT :=.exe
  ifneq (,$(findstring DMD,$(shell $(DC) 2>/dev/null | head -1)))
    $(info Compiler is DMD)
    OBJ_EXT :=.obj
  else
    # LDC uses a .o extension on Windows
    $(info Compiler is NOT DMD)
    OBJ_EXT :=.o
  endif
else
  # Non-windows, no ext for an executable
  OBJ_EXT :=.o
  EXE_EXT :=
endif

# Adding the -release flag on DMD causes linker errors for some reason
# (even with -allinst)
ifeq (dmd,$(DC))
  RELEASE_FLAGS         += -O -noboundscheck -inline -release
else
  RELEASE_FLAGS         += -O -release -noboundscheck -inline
endif

# ldmd2 has a bug when including debug symbols in (AT&T asm printer)
ifeq (ldmd2,$(DC))
  DEBUG_FLAGS           += -debug
else
  DEBUG_FLAGS           += -debug -gc
endif

# Ensure submodules are cloned
GIT_SUBMODULE_UPDATE := $(shell git submodule update --init)

SPEEDTEST_FLAGS       += $(RELEASE_FLAGS) -version=SpeedTest
UNITTEST_FLAGS        += -unittest $(DEBUG_FLAGS)
UNITTEST_DISKIO_FLAGS += $(UNITTEST_FLAGS) -version=TestOnDiskPersistence

SERVER_FILES = \
  src/server/server.d \
  src/server/context.d \
  src/server/connection_handler.d

CLIENT_FILES = src/client.d
TEST_RUNNER_FILES = src/test_runner.d

SERVER_OBJ = server$(OBJ_EXT)
CLIENT_OBJ = client$(OBJ_EXT)
TEST_RUNNER_OBJ = test_runner$(OBJ_EXT)

SERVER_BIN = server$(EXE_EXT)
CLIENT_BIN = client$(EXE_EXT)
TEST_RUNNER_BIN = test_runner$(EXE_EXT)

BLOOM_DIR = vendor/bloom/src

DIQS_DIR   := src
DIQS_OBJ   := diqs$(OBJ_EXT)
DIQS_FILES := \
  src/image_db/bucket.d \
  src/image_db/bucket_manager.d \
  src/image_db/all.d \
  src/image_db/mem_db.d \
  src/image_db/base_db.d \
  src/image_db/level_db.d \
  src/image_db/level_db_listeners.d \
  src/image_db/interfaces/all.d \
  src/image_db/interfaces/persistable_db.d \
  src/image_db/interfaces/reservable_db.d \
  src/image_db/interfaces/queryable_db.d \
  src/image_db/interfaces/image_removable_db.d \
  src/persistence_layer/file_helpers.d \
  src/consts.d \
  src/delta_queue.d \
  src/haar.d \
  src/query.d \
  src/reserved_array.d \
  src/sig.d \
  src/types.d \
  src/util.d \
  $(BLOOM_DIR)/dawg/bloom.d

MAGICKWAND_OBJ   := magickwand$(OBJ_EXT)
MAGICKWAND_FILES := $(shell ls src/magick_wand/*.d)

MSGPACK_DIR   := vendor/msgpack-d/src
MSGPACK_OBJ   := msgpack$(OBJ_EXT)
MSGPACK_FILES := $(MSGPACK_DIR)/msgpack.d

PAYLOAD_FILES := $(shell ls src/net/*.d)
PAYLOAD_OBJ   := payload$(OBJ_EXT)

# D_LEVELDB_DIR   := vendor/d-leveldb
# D_LEVELDB_FILES := $(shell ls -r $(D_LEVELDB_DIR)/etc/**/*.d)

LEVELDB_DIR     := vendor/leveldb
LEVELDB_FILES   := $(shell ls -r $(LEVELDB_DIR)/deimos/**/*.d)

LEVELDB_OBJ     := leveldb$(OBJ_EXT)

ifneq ($(OS),Windows_NT)
  LIB_STRING := $(shell pkg-config --libs MagickWand) -lleveldb

  # Preprend -L onto each linker flag (required by (l)dmd)
  LIBS = $(foreach lib,$(LIB_STRING),-L$(lib))

  # Ends up looking like this:
  # LIBS := -L-L/opt/local/lib -L-lleveldb -L-lMagickWand -L-lMagickCore
endif
# ====================================================================

# COMMON_OBJS = $(MAGICKWAND_OBJ) $(VIBE_OBJ) $(DIQS_OBJ) $(MSGPACK_OBJ) $(PAYLOAD_OBJ)
COMMON_OBJS = $(MAGICKWAND_OBJ) $(DIQS_OBJ) $(MSGPACK_OBJ) $(PAYLOAD_OBJ) $(LEVELDB_OBJ)
ALL_OBJS    = $(CLIENT_OBJ) $(SERVER_OBJ) $(COMMON_OBJS)

INCLUDE_DIRS = -I$(MSGPACK_DIR) -I$(DIQS_DIR) -I$(LEVELDB_DIR) -I$(BLOOM_DIR)

DC_FLAGS += $(INCLUDE_DIRS)

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
unittest: $(ALL_BIN) $(TEST_RUNNER_BIN)
	./$(TEST_RUNNER_BIN)

.PHONY: unittest_diskio
unittest_diskio: DC_FLAGS += $(UNITTEST_DISKIO_FLAGS)
unittest_diskio: $(TEST_RUNNER_BIN)
	./$(TEST_RUNNER_BIN)

.PHONY: speedtest
speedtest: DC_FLAGS += $(SPEEDTEST_FLAGS)
speedtest: $(TEST_RUNNER_BIN)

# ==============================================================================
$(SERVER_BIN):      $(SERVER_OBJ) $(COMMON_OBJS)
	$(DC) $(DC_FLAGS) $(SERVER_OBJ) $(COMMON_OBJS) $(LIBS) -of$(SERVER_BIN)

$(SERVER_OBJ):      $(SERVER_FILES)
	$(DC) $(DC_FLAGS) $(SERVER_FILES)  -c -of$(SERVER_OBJ)
# ==============================================================================

# ==============================================================================
$(CLIENT_BIN):      $(CLIENT_OBJ) $(COMMON_OBJS)
	$(DC) $(DC_FLAGS) $(CLIENT_OBJ) $(COMMON_OBJS) $(LIBS) -of$(CLIENT_BIN)

$(CLIENT_OBJ):      $(CLIENT_FILES)
	$(DC) $(DC_FLAGS) $(CLIENT_FILES)  -c -of$(CLIENT_OBJ)
# ==============================================================================

# ==============================================================================
$(TEST_RUNNER_BIN): $(TEST_RUNNER_OBJ) $(COMMON_OBJS)
	$(DC) $(DC_FLAGS) $(TEST_RUNNER_OBJ) $(COMMON_OBJS) $(LIBS) -of$(TEST_RUNNER_BIN)

$(TEST_RUNNER_OBJ): $(TEST_RUNNER_FILES)
	$(DC) $(DC_FLAGS) $(TEST_RUNNER_FILES)  -c -of$(TEST_RUNNER_OBJ)
# ==============================================================================

$(PAYLOAD_OBJ):     $(PAYLOAD_FILES) $(DIQS_FILES)
	$(DC) $(DC_FLAGS) $(PAYLOAD_FILES) $(INCLUDE_DIRS) -c -of$(PAYLOAD_OBJ)

$(DIQS_OBJ):        $(DIQS_FILES)
	$(DC) $(DC_FLAGS) $(DIQS_FILES) -c -of$(DIQS_OBJ)

$(MSGPACK_OBJ):     $(MSGPACK_FILES)
	$(DC) $(DC_FLAGS) $(MSGPACK_FILES) -c -of$(MSGPACK_OBJ)

$(MAGICKWAND_OBJ):  $(MAGICKWAND_FILES)
	$(DC) $(DC_FLAGS) $(MAGICKWAND_FILES) -c -of$(MAGICKWAND_OBJ)

$(LEVELDB_OBJ):     $(LEVELDB_FILES)
	$(DC) $(DC_FLAGS) $(LEVELDB_FILES) $(D_LEVELDB_FILES) -c -of$(LEVELDB_OBJ)

.PHONY: clean
clean:
	rm -f $(TEST_RUNNER_BIN)
	rm -f $(SERVER_BIN)
	rm -f $(CLIENT_BIN)
	rm -rf bin/*.*
	rm -f $(ALL_OBJS)
	rm -rf *.exe
