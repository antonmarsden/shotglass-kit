// shotglass-kit/blend: darken.glsl
//
// Blend pass: darken. The darker of picture and layer, per channel.
// Where the layer has coverage it shows by coverage x opacity; elsewhere the picture
// is untouched. Maths in modes.glsl.
// sound: picture only
//   e.g.  [[layer]] scene = "layers/leak.glsl"   blend = "blend/darken"   opacity = 0.8
#include "modes.glsl"

vec4 blend(vec2 uv) {
    vec4 b = getBase(uv);
    vec4 l = getLayer(uv);
    return kit_blend_composite(b, l, kit_blend_darken(b.rgb, kit_blend_source(l)));
}
