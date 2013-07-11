module types;

/**
 * Ubiquitous types found throught the program
 */

import consts : NumSigCoeffs;

alias image_id_t = size_t;
alias coeff_t    = float;
alias coeffi_t   = short;
alias chan_t     = ubyte;
alias dc_t       = float;
alias sig_t      = coeffi_t[NumSigCoeffs];
alias res_t      = ushort;
