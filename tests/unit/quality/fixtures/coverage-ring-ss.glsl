// Reference coverage from 16x16 samples per pixel.
#include <kit/sdf.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = fragCoord - 0.5 * iResolution.xy - vec2(0.1875, 0.3125);
    const float r = 25.0;
    const float width_px = 0.75;
    float ink = 0.0;
    for (int y = 0; y < 16; ++y) {
        for (int x = 0; x < 16; ++x) {
            vec2 offset = (vec2(float(x), float(y)) + 0.5) / 16.0 - 0.5;
            ink += float(abs(kit_sd_circle(p + offset, r)) < 0.5 * width_px);
        }
    }
    ink /= 256.0;
    fragColor = vec4(vec3(1.0 - ink), 1.0);
}
