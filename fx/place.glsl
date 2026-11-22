// shotglass-kit/fx: place.glsl
//
// Places a picture in the frame, keeping its proportions: a logo bug, a picture-in-
// picture, a framed insert. Transparent everywhere else; its own alpha (a PNG's) is kept,
// edges are antialiased over a pixel. Assumes straight alpha, which is what `[textures]`
// images and `@picture` are.
//   channels  ["logo"]                   iChannel0 is the picture (a [textures] name, or "@picture")
//   uniforms (animatable):
//     uPos   vec2, 0..1 of the frame     where the anchor point goes (default 0.5, 0.5)
//     uSize  float, frame heights        the picture's height (default 0.25)
//   params:
//     anchor  vec2, 0..1 of the picture  the point of the picture put at uPos; (1, 1) is its
//                                        top right corner, so a logo can sit 0.04 from the
//                                        corner at any aspect (default 0.5, 0.5)
//   cost: 1 texture read
//   e.g.  [[layer]]  type = "fx/place"  channels = ["logo"]  scale = 1
//         params = { anchor = [1.0, 1.0] }  uniforms.uPos = [0.96, 0.94]  uniforms.uSize = 0.1
// sound: picture only
#include "ops.glsl"
#ifndef SG_HAS_uPos
const vec2 uPos = vec2(0.5);
#endif
#ifndef SG_HAS_uSize
const float uSize = 0.25;
#endif
#ifndef anchor
#define anchor vec2(0.5)
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iChannelResolution[0].xy;
    vec3 q = kit_fx_place(fragCoord / iResolution.xy, iResolution.x / iResolution.y,
                          res.x / max(res.y, 1.0), uPos, uSize, vec2(anchor), 1.0 / iResolution.y);
    vec4 t = texture(iChannel0, q.xy);
    fragColor = vec4(t.rgb, t.a * q.z);
}
