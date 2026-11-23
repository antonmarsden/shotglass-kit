// shotglass-kit/fx: vignette.glsl
//
// Darkens (or tints) the corners. A transparent layer with no input: it paints the
// vignette colour with alpha rising towards the corners, so `opacity` scales it and any
// `blend` works (multiply gives a deeper one). The falloff is the same as core's
// kit_vignette.
//   uniforms (animatable):
//     uAmount    float, 0..1   how covered the corners get (default 0.4)
//     uSoftness  float, 0..1   how far in it starts; 1 = from the centre (default 0.6)
//   params:
//     color  vec3, 0..1        the vignette colour (default black)
//   cost: a few arithmetic ops
//   e.g.  [[layer]]  type = "fx/vignette"  uniforms.uAmount = 0.5  params = { color = [0.1, 0.0, 0.0] }
// sound: picture only
#include "ops.glsl"
#ifndef SG_HAS_uAmount
const float uAmount = 0.4;
#endif
#ifndef SG_HAS_uSoftness
const float uSoftness = 0.6;
#endif
#ifndef color
#define color vec3(0.0)
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = vec4(vec3(color), kit_fx_vignette(uv, uAmount, uSoftness));
}
