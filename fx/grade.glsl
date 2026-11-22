// shotglass-kit/fx: grade.glsl
//
// Colour grade of the picture below the layer: exposure, lift and gain, contrast,
// saturation, in that order. Works on display colour (what is on screen), clamped to
// 0..1. At the defaults it changes nothing. The layer's opacity is the grade's strength.
//   channels  ["@input"]                 iChannel0 is the picture to grade
//   uniforms (animatable, film `uniforms.<name>`):
//     uExposure    float, stops           brighter by 2^uExposure (default 0)
//     uContrast    float, 1 = none        stretches around mid grey (default 1)
//     uSaturation  float, 0..2, 1 = none  0 is grey (Rec. 709 luma) (default 1)
//   params (`params = { ... }`):
//     lift  float or vec3, 0..1           raises the blacks, whites stay (default 0)
//     gain  float or vec3                 multiplies, per channel (default 1)
//   cost: 1 texture read
//   e.g.  [[layer]]  type = "fx/grade"  channels = ["@input"]  params = { lift = [0.02, 0.0, 0.04] }
//         uniforms.uExposure = { keys = [[0, -2.0], [3, 0.0]] }
// sound: picture only
#include "ops.glsl"
#ifndef SG_HAS_uExposure
const float uExposure = 0.0;
#endif
#ifndef SG_HAS_uContrast
const float uContrast = 1.0;
#endif
#ifndef SG_HAS_uSaturation
const float uSaturation = 1.0;
#endif
#ifndef lift
#define lift vec3(0.0)
#endif
#ifndef gain
#define gain vec3(1.0)
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 c = texture(iChannel0, fragCoord / iResolution.xy).rgb;
    fragColor = vec4(kit_fx_grade(c, uExposure, uContrast, uSaturation, vec3(lift), vec3(gain)), 1.0);
}
