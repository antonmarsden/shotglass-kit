// The upper rings move at 3 pixels/second (0.125 px/frame at 24 fps).
// Left: point sampling. Middle: derivative coverage. Right: 16x16 supersampling.
// Bottom: a filled disc with a 4 px outline in each panel.
#include <kit/sdf.glsl>
#include <kit/sdf_coverage.glsl>

vec2 coverage_reference(vec2 p, float r, float width_px) {
    vec2 sum = vec2(0.0);
    for (int y = 0; y < 16; ++y) {
        for (int x = 0; x < 16; ++x) {
            vec2 offset = (vec2(float(x), float(y)) + 0.5) / 16.0 - 0.5;
            float d = kit_sd_circle(p + offset, r);
            sum += vec2(float(d < 0.0), float(abs(d) < 0.5 * width_px));
        }
    }
    return sum / 256.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 size = iResolution.xy;
    // Whole-pixel panel offsets preserve the same sampling phase in all three panels.
    float panel_width = floor(size.x / 3.0);
    float panel = min(floor(fragCoord.x / panel_width), 2.0);
    float center_x = (panel + 0.5) * panel_width;
    float r = min(0.15 * size.y, 0.11 * size.x);
    vec2 p = fragCoord - vec2(center_x, 0.72 * size.y);
    p.x -= 3.0 * iShotTime;
    vec2 q = fragCoord - vec2(center_x, 0.28 * size.y);

    float ring = kit_sd_circle(p, r);
    float d = kit_sd_circle(q, r);
    float thin = kit_sd_outline(ring, 0.75);
    vec2 disc = vec2(kit_sd_fill(d), kit_sd_outline(d, 4.0));
    if (panel == 0.0) {
        thin = float(abs(ring) < 0.375);
        disc = vec2(float(d < 0.0), float(abs(d) < 2.0));
    } else if (panel == 2.0) {
        thin = coverage_reference(p, r, 0.75).y;
        disc = coverage_reference(q, r, 4.0);
    }

    vec3 col = mix(vec3(0.96), vec3(0.46, 0.73, 0.81), disc.x);
    col = mix(col, vec3(0.04), max(thin, disc.y));
    if (abs(fragCoord.x - panel_width) < 1.0 ||
        abs(fragCoord.x - 2.0 * panel_width) < 1.0) col = vec3(0.78);
    fragColor = vec4(col, 1.0);
}
