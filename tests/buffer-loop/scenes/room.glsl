// A dark room for the incense: a warm wall fading into shadow, a wooden shelf, and
// two incense sticks in a small holder, their tips glowing (brighter on the beat of
// the loop, so it repeats exactly).
#include <kit/sdf.glsl>
#include <kit/noise.glsl>
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    vec2 p = fragCoord / iResolution.y;
    float px = 1.0 / iResolution.y;
    vec3 col = vec3(0.035, 0.022, 0.016) * (0.6 + 0.6 * exp2(-pow(length(p - vec2(0.5 * aspect, 0.25)), 2.0) * 3.0));
    col *= 0.9 + 0.1 * kit_value_noise(p * vec2(3.0, 40.0));
    // Shelf.
    if (p.y < 0.16) col = vec3(0.06, 0.035, 0.02) * (0.7 + 0.3 * kit_value_noise(p * vec2(60.0, 4.0)));
    // Holder.
    float holder = kit_sd_box(p - vec2(0.5 * aspect, 0.18), vec2(0.06, 0.02));
    col = mix(col, vec3(0.02, 0.018, 0.016), 1.0 - smoothstep(0.0, px, holder));
    // Sticks and tips (the buffer emits from the same tips).
    vec2 tips[2] = vec2[2](vec2(0.5 * aspect - 0.025, 0.47), vec2(0.5 * aspect + 0.03, 0.43));
    for (int i = 0; i < 2; i++) {
        float stick = kit_sd_segment(p, vec2(0.5 * aspect + (i == 0 ? -0.01 : 0.01), 0.19), tips[i]) - 0.003;
        col = mix(col, vec3(0.04, 0.02, 0.012), 1.0 - smoothstep(0.0, px, stick));
        float pulse = 0.8 + 0.2 * sin(6.28318531 * (iTime / MOVIE_DURATION * 2.0 + float(i) * 0.3));
        col += vec3(1.0, 0.35, 0.08) * pulse * exp2(-dot(p - tips[i], p - tips[i]) / (px * px * 6.0));
    }
    fragColor = vec4(kit_srgb_encode(col * kit_vignette(uv, 0.5, 0.6)), 1.0);
}
