// Binary coverage sampled at the pixel center.
#include <kit/sdf.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = fragCoord - 0.5 * iResolution.xy - vec2(0.1875, 0.3125);
    const float r = 25.0;
    const float width_px = 0.75;
    float ink = float(abs(kit_sd_circle(p, r)) < 0.5 * width_px);
    fragColor = vec4(vec3(1.0 - ink), 1.0);
}
