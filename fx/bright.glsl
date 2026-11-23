// shotglass-kit/fx: bright.glsl
//
// First pass of the bloom recipe: keeps what is brighter than a threshold in the picture
// below, and black elsewhere. Run it as a hidden helper layer (`opacity = 0`, usually at
// `scale = 0.5`) and read it from the blur layers with "@<id>". See blur.glsl for the
// whole recipe. Needs shotglass 0.1.5 for the "@<id>" read.
//   channels  ["@input"]                 iChannel0 is the picture below
//   uniforms (animatable):
//     uThreshold  float, 0..1            luma where the glow starts (default 0.6)
//   params:
//     knee  float, 0..1                  how far above uThreshold it takes to reach full
//                                        strength; 0 is a hard cut (default 0.25)
//   cost: 1 texture read
//   e.g.  [[layer]]  id = "bright"  type = "fx/bright"  opacity = 0  scale = 0.5  channels = ["@input"]
// sound: picture only
#include "ops.glsl"
#ifndef SG_HAS_uThreshold
const float uThreshold = 0.6;
#endif
#ifndef knee
#define knee 0.25
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 c = texture(iChannel0, fragCoord / iResolution.xy).rgb;
    fragColor = vec4(kit_fx_bright(c, uThreshold, knee), 1.0);
}
