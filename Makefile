# DC = dmd
DC := ~/code/d/ldc/build-ldc2-x64/bin/Debug/ldmd2
ifeq (64,$(MODEL))
  DC_FLAGS = -m64
endif

IMPORT_DIRS := src # vendor

RELEASE_FLAGS  = -release -O
DEBUG_FLAGS    = -debug -g -dw -unittest
UNITTEST_FLAGS = $(DEBUG_FLAGS)

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
  O_EXT = o
  DIQS_BIN = bin\\diqs.exe

  # Change this to your linker
  ifeq ($(MODEL),64)
    LINK = /c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio\ 10.0/VC/bin/amd64/link.exe
    LINK_FLAGS = -DEBUG -NOLOGO \
      -SUBSYSTEM:CONSOLE \
      "/LIBPATH:lib\win\64" \
      "/LIBPATH:C:\dmd2\src\phobos" \
      "/LIBPATH:C:\Program Files\Microsoft SDKs\Windows\v7.1\Lib\x64" \
      "/LIBPATH:C:\Users\dylank\code\d\ldc\build-ldc2-x64\lib\Debug" \
      "/LIBPATH:C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\lib\amd64" \
      CORE_RL_wand_.lib phobos-ldc.lib kernel32.lib user32.lib gdi32.lib winspool.lib shell32.lib ole32.lib oleaut32.lib uuid.lib comdlg32.lib advapi32.lib \
      "/OUT:$(DIQS_BIN)"
    # LINK = $(DC)
    # LINK_FLAGS = -of$(DIQS_BIN) -v
  endif

else
  O_EXT = o
  DIQS_BIN = bin/diqs
endif

LINK ?= $(DC)
LINK_FLAGS ?= -of$(DIQS_BIN) -g

# Build the import directory string out of the given import directories
# (append -I to each directory)
IMPORT_DIR_FLAGS := $(foreach dir,$(IMPORT_DIRS),-I$(dir))

# A list of object files to build (rules for them are defined below)
# OBJ_FILES is the list of object files to link to build the executable
OBJ_LIST := diqs magick_wand image_db # vendor
OBJ_FILES := $(foreach name,$(OBJ_LIST),bin/$(name).$(O_EXT))

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

$(DIQS_BIN): $(OBJ_FILES)
	$(LINK) $(OBJ_FILES) $(LINK_FLAGS)

# $1: The object name (sans ext)
# $2: source files for this object
# $3: Compiler flags
define MAKE_OBJ_FILE
bin/$(1).$(O_EXT):
	$(DC) -c $$(DC_FLAGS) $(IMPORT_DIR_FLAGS) $(2) -ofbin/$(1).$(O_EXT)
endef

# VENDOR_FILES = \
#   vendor/dcollections/HashMap.d \
#   vendor/dcollections/Hash.d \
#   vendor/dcollections/Link.d \
#   vendor/dcollections/DefaultAllocator.d \
#   vendor/dcollections/util.d \
#   vendor/dcollections/DefaultFunctions.d \
#   vendor/dcollections/model/Map.d \
#   vendor/dcollections/model/Keyed.d \
#   vendor/dcollections/model/Iterator.d
# $(eval $(call MAKE_OBJ_FILE,vendor,$(VENDOR_FILES)))

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
