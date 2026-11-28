// The terminal's screen in the monitor (iChannel0 is the room): the phosphor glow
// (iChannel1) through barrel distortion, scanlines and a soft bloom (kit_buf_box),
// with a glass sheen. Outside the screen the room shows through.
#include <kit/sdf.glsl>
#include <kit/color.glsl>
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec3 room = kit_srgb_decode(texture(iChannel0, uv).rgb);
    vec2 half_ = vec2(0.6, 0.41);
    vec2 s = p / half_;                                   // -1..1 across the screen
    s *= 1.0 + 0.08 * dot(s, s);                          // barrel
    float inside = 1.0 - smoothstep(-0.01, 0.0, kit_sd_box(s, vec2(1.0)) - 0.0);
    vec2 su = s * 0.5 + 0.5;
    vec2 size = vec2(textureSize(iChannel1, 0));
    vec3 glow = kit_buf_sample(iChannel1, su, false).rgb;
    vec3 bloom = kit_buf_box(iChannel1, ivec2(su * size), false).rgb;
    float scan = 0.75 + 0.25 * sin(su.y * size.y * 3.14159265 * 2.0);
    vec3 screen = vec3(0.004, 0.012, 0.006) + glow * scan + 0.35 * bloom;
    screen += 0.03 * (1.0 - smoothstep(0.0, 0.8, length(s - vec2(-0.4, 0.5))));
    screen *= 1.0 - 0.35 * dot(s, s) * 0.5;
    vec3 col = mix(room, screen, inside);
    fragColor = vec4(kit_srgb_encode(kit_aces(col * 1.2)), 1.0);
}
