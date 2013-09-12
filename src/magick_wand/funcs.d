module magick_wand.funcs;

import magick_wand.types :
  WandPtr,
  MagickBooleanType,
  StorageType,
  FilterTypes;

alias ssize_t = ptrdiff_t;

extern(C) {
	MagickBooleanType MagickReadImage(WandPtr, const char*);
	MagickBooleanType IsMagickWand(WandPtr);
	MagickBooleanType MagickExportImagePixels(WandPtr wand,
	  const ssize_t x,const ssize_t y,const size_t columns,
	  const size_t rows,const char *map,const StorageType storage,
	  void *pixels);
	MagickBooleanType MagickImportImagePixels(WandPtr *wand,
	  const ssize_t x,const ssize_t y,const size_t columns,
	  const size_t rows,const char *map,const StorageType storage,
	  const void *pixels);

	MagickBooleanType MagickScaleImage(WandPtr wand,
	  const size_t columns,const size_t rows);
	MagickBooleanType MagickResizeImage(WandPtr wand,
	  const size_t columns,const size_t rows,
	  const FilterTypes filter,const double blur);

	size_t MagickGetImageWidth(WandPtr wand);
	size_t MagickGetImageHeight(WandPtr wand);

	void  ClearMagickWand(WandPtr);
	void  MagickWandGenesis();
	void  MagickWandTerminus();

	WandPtr NewMagickWand();
	WandPtr DestroyMagickWand(WandPtr);
}
