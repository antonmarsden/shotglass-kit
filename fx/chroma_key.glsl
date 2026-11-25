// shotglass-kit/fx: chroma_key.glsl
//
// Keys a straight-alpha display-colour plate over the picture below. Fits the plate
// to the frame. Samples the original RGB for the matte and independently removes
// spill along the key's chroma direction. The engine composites the straight output.
//   channels  ["plate"]              iChannel0 is a [textures] image or sequence
//   uniforms (animatable):
//     uKeyColor   vec3, display RGB   screen colour (default 0, 1, 0)
//     uThreshold  float, 0..2         clear below and at this chroma distance (default 0.12)
//     uSoftness   float, 0..2         extra distance to full coverage (default 0.30; 0 = hard)
//     uDespill    float, 0..1         removal of key-coloured spill (default 1)
//   cost: 1 texture read
//   e.g.  [[layer]]  type = "fx/chroma_key"  channels = ["plate"]
//         uniforms.uKeyColor = [0.08, 0.84, 0.13]
// sound: picture only
#include "ops.glsl"
#ifndef SG_HAS_uKeyColor
const vec3 uKeyColor = vec3(0.0, 1.0, 0.0);
#endif
#ifndef SG_HAS_uThreshold
const float uThreshold = 0.12;
#endif
#ifndef SG_HAS_uSoftness
const float uSoftness = 0.30;
#endif
#ifndef SG_HAS_uDespill
const float uDespill = 1.0;
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 plate = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = kit_fx_chroma_key(plate, uKeyColor, uThreshold, uSoftness, uDespill);
}
