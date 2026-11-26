// shotglass-kit/fx: dither.glsl
//
// Quantizes display RGB with a fixed blue-noise pattern, one texel per layer pixel.
// Add it at full resolution, after grading and glow. Writes an opaque picture.
//   channels  iChannel0: "@input"; iChannel1: "<kit/textures/blue-noise-64.png>"
//             Bind the tile with filter = "nearest", srgb = false.
//   params:
//     ditherLevels  integer levels per channel, 2..256 (default 64)
//   cost: 2 texture reads and 3 scalar dither operations
//   e.g. id = "dither"  type = "fx/dither"  scale = 1  params = { ditherLevels = 32 }
// sound: picture only
#include "dither-ops.glsl"

#ifndef ditherLevels
#define ditherLevels 64.0
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 col = texture(iChannel0, fragCoord / iResolution.xy).rgb;
    ivec2 pixel = ivec2(floor(fragCoord)) % textureSize(iChannel1, 0);
    float noise = texelFetch(iChannel1, pixel, 0).r;
    fragColor = vec4(kit_fx_dither(col, ditherLevels, noise), 1.0);
}
