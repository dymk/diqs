module magick_wand.types;

alias MagickBooleanType = bool;
alias WandPtr = void*;

enum MagickTrue = true;
enum MagickFalse = false;

// "magick/constitute.h", line 25
enum StorageType {
	UndefinedPixel,
	CharPixel,
	DoublePixel,
	FloatPixel,
	IntegerPixel,
	LongPixel,
	QuantumPixel,
	ShortPixel
}

// "magick/resample.h", line 32
enum FilterTypes
{
	UndefinedFilter,
	PointFilter,
	BoxFilter,
	TriangleFilter,
	HermiteFilter,
	HanningFilter,
	HammingFilter,
	BlackmanFilter,
	GaussianFilter,
	QuadraticFilter,
	CubicFilter,
	CatromFilter,
	MitchellFilter,
	JincFilter,
	SincFilter,
	SincFastFilter,
	KaiserFilter,
	WelshFilter,
	ParzenFilter,
	BohmanFilter,
	BartlettFilter,
	LagrangeFilter,
	LanczosFilter,
	LanczosSharpFilter,
	Lanczos2Filter,
	Lanczos2SharpFilter,
	RobidouxFilter,
	RobidouxSharpFilter,
	CosineFilter,
	SplineFilter,
	LanczosRadiusFilter,
	SentinelFilter  /* a count of all the filters, not a real filter */
}
