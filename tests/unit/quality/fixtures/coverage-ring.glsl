// Compare derivative coverage to a box-filtered binary ring in screen pixels.
#include <kit/sdf.glsl>
#include <kit/sdf_coverage.glsl>

#ifndef COVERAGE_TEST_MODE
#define COVERAGE_TEST_MODE 0
#endif
#ifndef COVERAGE_TEST_WIDTH
#define COVERAGE_TEST_WIDTH 0.75
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = fragCoord - 0.5 * iResolution.xy - vec2(0.1875, 0.3125);
    const float r = 25.0;
    const float width_px = COVERAGE_TEST_WIDTH;
#if COVERAGE_TEST_MODE == 1
    float ink = 0.0;
    for (int y = 0; y < 16; ++y) {
        for (int x = 0; x < 16; ++x) {
            vec2 offset = (vec2(float(x), float(y)) + 0.5) / 16.0 - 0.5;
            ink += float(abs(kit_sd_circle(p + offset, r)) < 0.5 * width_px);
        }
    }
    ink /= 256.0;
#elif COVERAGE_TEST_MODE == 2
    float ink = float(abs(kit_sd_circle(p, r)) < 0.5 * width_px);
#else
    float ink = kit_sd_outline(kit_sd_circle(p, r), width_px);
#endif
    fragColor = vec4(vec3(1.0 - ink), 1.0);
}
