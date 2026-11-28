// A dark room with an old monitor: a beige bezel round a curved screen. The layer
// above draws the screen's picture into the hole.
#include <kit/sdf.glsl>
#include <kit/noise.glsl>
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec3 col = vec3(0.012, 0.012, 0.016) * (0.8 + 0.4 * kit_value_noise(p * 3.0));
    float bezel = kit_sd_box(p, vec2(0.62, 0.43)) - 0.04;
    float px = 1.0 / iResolution.y;
    vec3 beige = vec3(0.30, 0.27, 0.22) * (0.75 + 0.25 * smoothstep(-0.45, 0.45, p.y));
    col = mix(col, beige, 1.0 - smoothstep(0.0, px, bezel));
    // A faint green spill onto the bezel from the screen.
    col += vec3(0.0, 0.03, 0.01) * exp2(-max(bezel + 0.04, 0.0) * 30.0);
    fragColor = vec4(kit_srgb_encode(col * kit_vignette(uv, 0.4, 0.7)), 1.0);
}
