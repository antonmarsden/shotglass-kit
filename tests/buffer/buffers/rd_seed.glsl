// Inoculation for each reset (init pass of rd1): A = 1 everywhere, B where the culture
// was dropped on the agar (all inside the dish, radius 0.42). The first layout is a ring with a few drops (coral); the one
// after the reset at 2 s a scatter of drops plus fine speckle (mitosis). The preset
// index rides along in z. Positions in frame heights, so the layout keeps its shape
// at any buffer size.
#include <kit/noise.glsl>
#include <buffer/math.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float aspect = iResolution.x / iResolution.y;
    vec2 p = fragCoord / iResolution.y;
    vec2 c = vec2(0.5 * aspect, 0.5);
    int which = iTime >= 1.99 ? 1 : 0;
    float b = 0.0;
    if (which == 0) {
        float ring = kit_buf_seed_disc(p, c, 0.16, 0.01) - kit_buf_seed_disc(p, c, 0.13, 0.01);
        b = max(b, ring);
        for (int i = 0; i < 5; i++) {
            float a = 6.28318531 * kit_hash(ivec2(i, 1));
            vec2 q = c + (0.22 + 0.12 * kit_hash(ivec2(i, 2))) * vec2(cos(a), sin(a));
            b = max(b, kit_buf_seed_disc(p, q, 0.02, 0.01));
        }
    } else {
        for (int i = 0; i < 9; i++) {
            float a = 6.28318531 * kit_hash(ivec2(i, 7));
            vec2 q = c + 0.33 * sqrt(kit_hash(ivec2(i, 8))) * vec2(cos(a), sin(a));
            b = max(b, kit_buf_seed_disc(p, q, 0.03, 0.01));
        }
        b = max(b, kit_buf_seed_noise(ivec2(fragCoord) / 4, 11, 0.01) * step(length(p - c), 0.38));
    }
    fragColor = vec4(1.0, b, which == 0 ? 0.0 : 1.0, 1.0);
}
