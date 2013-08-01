DC = dmd
IMPORT_DIRS := vendor src

RELEASE_FLAGS  = -release -O
DEBUG_FLAGS    = -debug -g -dw -unittest
# Perhaps this can be changed in the future, but for now it'll work just fine
UNITTEST_FLAGS = $(DEBUG_FLAGS)

# By default, build debug
DC_FLAGS = $(DEBUG_FLAGS)

# Detect the DMD version, because -inline causes problems in 2.063
ifneq (,$(findstring 2.063,$(shell $(DC) | head -1)))
  $(info -----------------------------------------------------------------------------------------)
  $(info DMD 2.063's -inline won't work in this application. It is highly suggested you use 2.064.)
  $(info -----------------------------------------------------------------------------------------)
else
  RELEASE_FLAGS += -inline
endif

# Detect operating system to set object file extension
# and correct backslash/forwardslash bugs in DMD's linker
ifneq (,$(findstring NT,$(OS)))
  O_EXT = obj
  DIQS_BIN = bin\\diqs.exe
else
  O_EXT = o
  DIQS_BIN = bin/diqs
endif

# Build the import directory string out of the given import directories
# (append -I to each directory)
IMPORT_DIR_FLAGS := $(foreach dir,$(IMPORT_DIRS),-I$(dir))

# A list of object files to build (rules for them are defined below)
# OBJ_FILES is the list of object files to link to build the executable
OBJ_LIST := vendor magick_wand image_db diqs
OBJ_FILES := $(foreach name,$(OBJ_LIST),bin/$(name).$(O_EXT))

.PHONY: all
all: DC_FLAGS ?= $(DEBUG_FLAGS)
all: $(DIQS_BIN)

.PHONY: debug
debug: DC_FLAGS = $(DEBUG_FLAGS)
debug: all

.PHONY: release
release: DC_FLAGS = $(RELEASE_FLAGS)
release: all

.PHONY: unittest
unittest: DC_FLAGS = $(UNITTEST_FLAGS)
unittest: all
	$(DIQS_BIN)

$(DIQS_BIN): $(OBJ_FILES)
	$(DC) -of$(DIQS_BIN) $(OBJ_FILES) -g

# $1: The object name (sans ext)
# $2: source files for this object
# $3: Compiler flags
define MAKE_OBJ_FILE
bin/$(1).$(O_EXT):
	$(DC) -c $$(DC_FLAGS) $(IMPORT_DIR_FLAGS) $(2) -ofbin/$(1).$(O_EXT)
endef

VENDOR_FILES = \
  vendor/dcollections/HashMap.d \
  vendor/dcollections/Hash.d \
  vendor/dcollections/Link.d \
  vendor/dcollections/DefaultAllocator.d \
  vendor/dcollections/util.d \
  vendor/dcollections/DefaultFunctions.d \
  vendor/dcollections/model/Map.d \
  vendor/dcollections/model/Keyed.d \
  vendor/dcollections/model/Iterator.d
$(eval $(call MAKE_OBJ_FILE,vendor,$(VENDOR_FILES)))

MAGICK_WAND_FILES = \
  src/magick_wand/all.d \
  src/magick_wand/colorspace.d \
  src/magick_wand/funcs.d \
  src/magick_wand/types.d \
  src/magick_wand/wand.d
$(eval $(call MAKE_OBJ_FILE,magick_wand,$(MAGICK_WAND_FILES)))

IMAGE_DB_FILES = \
  src/image_db/all.d \
  src/image_db/base_db.d \
  src/image_db/bucket.d \
  src/image_db/bucket_manager.d \
  src/image_db/file_db.d \
  src/image_db/id_set.d \
  src/image_db/mem_db.d
$(eval $(call MAKE_OBJ_FILE,image_db,$(IMAGE_DB_FILES)))

DIQS_FILES = \
  src/consts.d \
  src/diqs.d \
  src/haar.d \
  src/reserved_array.d \
  src/sig.d \
  src/types.d \
  src/util.d
$(eval $(call MAKE_OBJ_FILE,diqs,$(DIQS_FILES)))

# include to force clean to run before other tasks
.PHONY: clean
clean:
	rm -rf bin/*.*
	rm -rf *.obj
	rm -rf *.exe
