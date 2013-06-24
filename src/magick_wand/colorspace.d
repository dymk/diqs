module magick_wand.colorspace;

struct RGB {
	ubyte r, g, b;

	static RGB from_rgb(RGB r) {
		return r;
	}
}

struct YIQ {
	ubyte y;
	byte i, q;

	static YIQ from_rgb(RGB r) {
		return r.toYIQ();
	}
}

YIQ toYIQ(RGB c) {
	/*
	 * http://www.eembc.org/techlit/datasheets/yiq_consumer.pdf
	 */
	float
	  r = c.r,
	  g = c.g,
	  b = c.b;

	float y = (
	  (0.299 * r) +
	  (0.587 * g) +
	  (0.114 * b));
	float i = (
	  (0.596 * r) -
	  (0.275 * g) -
	  (0.321 * b));
	float q = (
	  (0.212 * r) -
	  (0.523 * g) +
	  (0.311 * b));

	return YIQ(cast(ubyte)y, cast(byte)i, cast(byte)q);
}

unittest {
	auto rgb = RGB(255, 255, 255);
	auto yiq = YIQ(255,   0,   0);
	auto rgb_2_yiq = rgb.toYIQ();
	assert(rgb_2_yiq == yiq);
}

RGB toRGB(YIQ c) {
	/*
	 * http://www.cs.rit.edu/~ncs/color/t_convert.html
	 */
	float y = c.y;
	float i = c.i;
	float q = c.q;

	float r = (
	  (1.000 * y) +
	  (0.956 * i) +
	  (0.621 * q));
	float g = (
	  (1.000 * y) -
	  (0.272 * i) -
	  (0.647 * q));
	float b = (
	  (1.000 * y) -
	  (1.105 * i) +
	  (1.702 * q));
	return RGB(cast(byte)r, cast(byte)g, cast(byte)b);
}

unittest {
	auto rgb = RGB(255, 255, 255);
	auto yiq = YIQ(255,   0,   0);
	auto yiq_2_rgb = yiq.toRGB();
	assert(yiq_2_rgb == rgb);
}
