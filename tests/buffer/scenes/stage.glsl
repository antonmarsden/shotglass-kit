// A dark studio backdrop for the feedback tunnel: near black with a faint warm pool
// of light, so the echoes read against it.
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec3 col = vec3(0.020, 0.012, 0.030) + vec3(0.05, 0.03, 0.06) * exp2(-dot(p, p) * 6.0);
    fragColor = vec4(kit_srgb_encode(col * kit_vignette(uv, 0.5, 0.6)), 1.0);
}
