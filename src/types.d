module types;

/**
 * Ubiquitous types found throught the program
 */

import consts : NumSigCoeffs;

alias image_id_t = size_t;
alias coeff_t    = short;
alias dc_t       = float;
alias sig_t      = coeff_t[NumSigCoeffs];
alias res_t      = ushort;


/**
 * Structs to represent image data in memory, and on the
 * disk.
 */
struct FullImageSig
{
	// Locations of the top NumSigCoeffs coefficients
	sig_t y, i, q;
}
struct FullImageDC
{
	// DC coefficents (first component) of the haar decomposed image
	dc_t y, i, q;
}
struct ImageRes
{
	res_t width, height;
}

struct ImageData
{
	FullImageSig sig;
	FullImageDC dc;
	ImageRes res;
}

/// For now, used when serializing image data to the disk
/// so an immutable user ID can be associated with it
struct IDImageData
{
	image_id_t user_id;
	ImageData img;
}
