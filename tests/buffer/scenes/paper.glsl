// Watercolour paper: warm off-white with a soft fibre texture and a little tooth.
#include <kit/noise.glsl>
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = fragCoord / iResolution.y;
    float fibre = kit_fbm(p * vec2(30.0, 8.0), 4);
    float tooth = kit_value_noise(p * 220.0);
    vec3 col = vec3(0.93, 0.89, 0.80) * (0.94 + 0.06 * fibre) * (0.97 + 0.03 * tooth);
    fragColor = vec4(col * mix(1.0, kit_vignette(uv, 0.25, 0.8), 0.6), 1.0);
}
