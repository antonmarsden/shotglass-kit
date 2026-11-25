// The upper rings move at 3 pixels/second (0.125 px/frame at 24 fps).
// Left: derivative coverage. Right: 16x16 supersampling of the same shapes.
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
    float center_x = 0.25 * size.x;
    float r = min(0.15 * size.y, 0.15 * size.x);
    vec2 p = fragCoord - vec2(center_x, 0.72 * size.y);
    p.x -= 3.0 * iShotTime;
    vec2 q = fragCoord - vec2(center_x, 0.28 * size.y);

    float thin = kit_sd_outline(kit_sd_circle(p, r), 0.75);
    float d = kit_sd_circle(q, r);
    vec2 disc = vec2(kit_sd_fill(d), kit_sd_outline(d, 4.0));
    if (fragCoord.x >= 0.5 * size.x) {
        vec2 panel = vec2(0.5 * size.x, 0.0);
        thin = coverage_reference(p - panel, r, 0.75).y;
        disc = coverage_reference(q - panel, r, 4.0);
    }

    vec3 col = mix(vec3(0.96), vec3(0.46, 0.73, 0.81), disc.x);
    col = mix(col, vec3(0.04), max(thin, disc.y));
    if (abs(fragCoord.x - 0.5 * size.x) < 1.0) col = vec3(0.78);
    fragColor = vec4(col, 1.0);
}
