// shotglass-kit/fx: letterbox.glsl
//
// Cinema bars: covers the frame outside a picture of the given aspect ratio (bars top
// and bottom when the frame is taller than that, left and right when it is wider). A
// transparent layer with no input; the bars are solid, edges antialiased over a pixel.
// Animate uAspect to slide the bars in.
//   uniforms (animatable):
//     uAspect  float, width / height   the picture area's aspect (default 2.39)
//   params:
//     color  vec3, 0..1                the bars' colour (default black)
//   cost: a few arithmetic ops
//   e.g.  [[layer]]  type = "fx/letterbox"  from = "closeup"  uniforms.uAspect = 2.0
// sound: picture only
#include "ops.glsl"
#ifndef SG_HAS_uAspect
const float uAspect = 2.39;
#endif
#ifndef color
#define color vec3(0.0)
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float bar = kit_fx_letterbox(uv, iResolution.x / iResolution.y, max(uAspect, 1e-3), 1.0 / iResolution.y);
    fragColor = vec4(vec3(color), bar);
}
