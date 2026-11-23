// shotglass-kit/fx: grain.glsl
//
// Film grain over the picture below the layer, new every frame. Deterministic: frame n
// always gets the same grain, so stills and exports match. Grain is one pixel of the
// layer, so `scale = 0.5` on the layer makes it twice as coarse. The layer's opacity
// scales the grain.
//   channels  ["@input"]                 iChannel0 is the picture to grain
//   uniforms (animatable):
//     uAmount  float, 0..0.2 typically   the grain's full range in colour units (default 0.06)
//   params:
//     colored  0 or 1                    1 = different grain per colour channel (default 0)
//   cost: 1 texture read, 1 or 3 hashes
//   e.g.  [[layer]]  type = "fx/grain"  channels = ["@input"]  scale = 0.5  opacity = 0.8
// sound: picture only
#include "ops.glsl"
#ifndef SG_HAS_uAmount
const float uAmount = 0.06;
#endif
#ifndef colored
#define colored 0.0
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 c = texture(iChannel0, fragCoord / iResolution.xy).rgb;
    fragColor = vec4(kit_fx_grain(c, fragCoord, iFrame, uAmount, colored), 1.0);
}
