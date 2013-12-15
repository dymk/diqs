module magick_wand.funcs;

import magick_wand.types;

alias ssize_t = ptrdiff_t;

extern(C) {
	//void free (void* ptr);

	MagickBooleanType MagickReadImage(WandPtr, const char*);
	MagickBooleanType IsMagickWand(WandPtr);
	MagickBooleanType MagickExportImagePixels(WandPtr wand,
	  const ssize_t x,const ssize_t y,const size_t columns,
	  const size_t rows,const char *map,const StorageType storage,
	  void *pixels);
	MagickBooleanType MagickImportImagePixels(WandPtr wand,
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

	size_t MagickGetNumberImages(WandPtr wand);
	MagickBooleanType MagickNewImage(WandPtr wand,
	    const size_t columns,const size_t rows,
	    const PixelWandPtr background);

	void  ClearMagickWand(WandPtr);
	void  MagickWandGenesis();
	void  MagickWandTerminus();

	WandPtr NewMagickWand();
	WandPtr DestroyMagickWand(WandPtr);

	void PixelSetRed(PixelWandPtr wand,const double red);
	void PixelSetGreen(PixelWandPtr wand,const double green);
	void PixelSetBlue(PixelWandPtr wand,const double blue);

	char* MagickGetException(const WandPtr wand, ExceptionType *severity);

	PixelWandPtr NewPixelWand();
	PixelWandPtr DestroyPixelWand(PixelWandPtr wand);
}
