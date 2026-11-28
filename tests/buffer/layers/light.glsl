// The long exposure over the street: the exposure buffer (iChannel1, linear light x
// seconds) plus a soft lens bloom (kit_buf_blur, a ring of taps) added at display
// time, over the plate, tonemapped so bright overlaps burn out to white. The
// road catches a dim reflection of the stroke.
#include <kit/color.glsl>
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 plate = kit_srgb_decode(texture(iChannel0, uv).rgb);
    vec2 size = vec2(textureSize(iChannel1, 0));
    ivec2 q = ivec2(uv * size);
    vec3 light = kit_buf_sample(iChannel1, uv, false).rgb;
    vec3 bloom = vec3(0.0);
    for (int i = 0; i < 4; i++) {
        float a = 1.5707963 * float(i) + 0.785398;
        ivec2 o = ivec2(floor(vec2(cos(a), sin(a)) * 4.0 + 0.5));
        bloom += kit_buf_blur(iChannel1, q + o, false).rgb;
    }
    vec3 col = plate + light + 0.06 * bloom;
    if (uv.y < 0.08) {
        vec2 m = vec2(uv.x, 0.16 - uv.y);
        col += 0.25 * kit_buf_sample(iChannel1, m, false).rgb;
    }
    fragColor = vec4(kit_srgb_encode(kit_aces(col)), 1.0);
}
