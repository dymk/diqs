all: diqs.exe

diqs.exe: vendor.obj diqs.obj
	dmd -ofdiqs.exe vendor.obj diqs.obj -g

vendor.obj:
	dmd -c -unittest \
	  -Ivendor/ \
	  vendor/dcollections/HashMap.d \
	  vendor/dcollections/Hash.d \
	  vendor/dcollections/Link.d \
	  vendor/dcollections/DefaultAllocator.d \
	  vendor/dcollections/util.d \
	  vendor/dcollections/DefaultFunctions.d \
	  vendor/dcollections/model/Map.d \
	  vendor/dcollections/model/Keyed.d \
	  vendor/dcollections/model/Iterator.d \
	  -ofvendor.obj

diqs.obj:
	dmd -c -unittest \
	  -Ivendor/ \
	  -Isrc/ \
	  src/image_db/all.d \
	  src/image_db/base_db.d \
	  src/image_db/bucket.d \
	  src/image_db/bucket_manager.d \
	  src/image_db/file_db.d \
	  src/image_db/id_set.d \
	  src/image_db/mem_db.d \
	  src/magick_wand/all.d \
	  src/magick_wand/colorspace.d \
	  src/magick_wand/funcs.d \
	  src/magick_wand/types.d \
	  src/magick_wand/wand.d \
	  src/consts.d \
	  src/diqs.d \
	  src/haar.d \
	  src/reserved_array.d \
	  src/sig.d \
	  src/types.d \
	  src/util.d \
	  -ofdiqs.obj

.PHONY: clean
clean:
	rm -rf *.obj
	rm -rf *.exe
