module types;

/**
 * Ubiquitous types found throught the program
 */

import consts : NumSigCoeffs, ImageArea;

alias intern_id_t = uint; // Internal ID for image data
alias user_id_t   = size_t;  // User facing immutable ID for image data
alias coeff_t     = float;
alias coeffi_t    = short;
alias chan_t      = ubyte;
alias dc_t        = float;
alias sig_t       = coeffi_t[NumSigCoeffs];
alias res_t       = ushort;
alias score_t     = int;

static assert(coeffi_t.max >= ImageArea);
static assert(coeffi_t.min <= -ImageArea);
