module magick_wand.all;

/**
 * The MagickWand Module: A selective wrapper around MagickWand for
 * fast and easy image resizing, color space conversion, and image
 * file loading.
 */

version(Windows) {
	version(X86_64) {
		pragma(lib, "lib\\win\\64\\CORE_RL_wand_");
	} else {
		// Many thanks to Destructionator for converting this to OMF
		pragma(lib, "lib\\win\\32\\CORE_RL_wand_omf_");
	}
} else version(Posix) {
	pragma(lib, "MagickWand");
	pragma(lib, "MagickCore");
}

public import magick_wand.types;
public import magick_wand.funcs;
public import magick_wand.colorspace;
public import magick_wand.wand;
