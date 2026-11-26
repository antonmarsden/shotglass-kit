// Derivative coverage of a wide ring.
#include <kit/sdf.glsl>
#include <kit/sdf_coverage.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = fragCoord - 0.5 * iResolution.xy - vec2(0.1875, 0.3125);
    const float r = 25.0;
    const float width_px = 4.0;
    float ink = kit_sd_outline(kit_sd_circle(p, r), width_px);
    fragColor = vec4(vec3(1.0 - ink), 1.0);
}
