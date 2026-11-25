// shotglass-kit/core: sdf_coverage.glsl
//
// Pixel coverage of a 2D signed distance field, negative inside. The distance
// should be locally smooth near the contour. Call in uniform fragment control
// flow so the distance derivatives are defined across the pixel quad.
// sound: picture only

// Fraction of a square pixel below an edge in the locally linear distance field.
// a and b are the larger and smaller projected half-extents of the pixel.
float kit_sd_coverage_internal(float edge, float a, float b) {
    float x = abs(edge);
    float tail;
    if (x >= a + b) {
        tail = 0.0;
    } else if (x <= a - b) {
        tail = 0.5 * (1.0 - x / a);
    } else {
        float t = a + b - x;
        tail = 0.125 * (t / a) * (t / b);
    }
    return edge < 0.0 ? tail : 1.0 - tail;
}

// kit_sd_fill(d): antialiased coverage inside the zero contour.
//   d   signed distance in the units of p; a locally constant field gives
//       full coverage for d < 0, zero for d > 0 and half coverage at d = 0
//   ->  0..1 coverage
//   e.g. float fill = kit_sd_fill(length(fragCoord - 100.0) - 40.0);
float kit_sd_fill(float d) {
    vec2 g = abs(vec2(dFdx(d), dFdy(d)));
    float scale = max(g.x, g.y);
    if (scale == 0.0) return 0.5 * (1.0 - sign(d));
    return kit_sd_coverage_internal(-d / scale, 0.5, 0.5 * (min(g.x, g.y) / scale));
}

// kit_sd_outline(d, width_px): antialiased coverage of a band centred on the zero contour.
//   d          signed distance in the units of p; a locally constant field gives zero coverage
//   width_px   full width in raster pixels, measured normal to the edge; <= 0 gives zero
//   ->         0..1 coverage
//   e.g. float ink = kit_sd_outline(length(fragCoord - 100.0) - 40.0, 0.75);
float kit_sd_outline(float d, float width_px) {
    vec2 g = abs(vec2(dFdx(d), dFdy(d)));
    float scale = max(g.x, g.y);
    if (scale == 0.0 || width_px <= 0.0) return 0.0;

    float slope = min(g.x, g.y) / scale;
    float half_width = 0.5 * width_px * length(vec2(1.0, slope));
    float distance = d / scale;
    // Integrate both edges against the same footprint, even when they overlap.
    return kit_sd_coverage_internal(half_width - distance, 0.5, 0.5 * slope)
         - kit_sd_coverage_internal(-half_width - distance, 0.5, 0.5 * slope);
}
