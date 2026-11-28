// The smoke (iChannel1, premultiplied density) over the room (iChannel0): thin blue
// grey where it's sparse, lit warm from the tips below, denser where it pools.
#include <kit/color.glsl>
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 room = kit_srgb_decode(texture(iChannel0, uv).rgb);
    float d = kit_buf_sample(iChannel1, uv, false).a;
    float density = 1.0 - exp2(-6.0 * d);
    vec3 tint = mix(vec3(0.9, 0.55, 0.3), vec3(0.45, 0.5, 0.6), smoothstep(0.45, 0.9, uv.y));
    vec3 col = mix(room, tint, density * 0.8);
    fragColor = vec4(kit_srgb_encode(col), 1.0);
}
