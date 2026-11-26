// shotglass-kit/fx: dither-ops.glsl
//
// The dither pass shares core's rounding. Keeping this include separate lets the
// other fx passes work in projects that don't declare the core library.
// sound: picture only
#include <shotglass-kit/core/noise.glsl>

// kit_fx_dither(col, levels, noise): quantizes display RGB with a shared blue-noise threshold.
//   col     display colour, clamped to 0..1 per channel
//   levels  output levels per channel, clamped to 2..256 and rounded to the nearest integer;
//           halves round up
//   noise   normalized 8-bit red texel from the kit blue-noise tile, 0..1
//   ->      one of the equally spaced 0..1 levels per channel, within one level step
//           of the clamped input; black, white and neutral greys stay neutral
//   cost: 3 scalar dither operations, with one shared threshold
//   e.g.   vec3 col = kit_fx_dither(vec3(0.4), 64.0, 0.25);
vec3 kit_fx_dither(vec3 col, float levels, float noise) {
    int count = int(floor(clamp(levels, 2.0, 256.0) + 0.5));
    float threshold = (255.0 * noise + 0.5) / 256.0;
    vec3 c = clamp(col, 0.0, 1.0);
    return vec3(kit_dither(c.r, count, threshold),
                kit_dither(c.g, count, threshold),
                kit_dither(c.b, count, threshold));
}
