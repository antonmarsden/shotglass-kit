// shotglass-kit/blend: screen.glsl
//
// Blend pass: screen. Lightens; black in the layer changes nothing (glows, light leaks, bloom).
// Where the layer has coverage it shows by coverage x opacity; elsewhere the picture
// is untouched. Maths in modes.glsl.
// sound: picture only
//   e.g.  [[layer]] scene = "layers/leak.glsl"   blend = "blend/screen"   opacity = 0.8
#include "modes.glsl"

vec4 blend(vec2 uv) {
    vec4 b = getBase(uv);
    vec4 l = getLayer(uv);
    return kit_blend_composite(b, l, kit_blend_screen(b.rgb, kit_blend_source(l)));
}
