// Ink seed for each reset (init pass of rd1): A = 1 everywhere, B where the brush
// touched the paper. The first layout is a ring with a few drops (coral); the one
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
            vec2 q = vec2(kit_hash(ivec2(i, 1)) * aspect, kit_hash(ivec2(i, 2)));
            b = max(b, kit_buf_seed_disc(p, q, 0.02, 0.01));
        }
    } else {
        for (int i = 0; i < 9; i++) {
            vec2 q = vec2((0.1 + 0.8 * kit_hash(ivec2(i, 7))) * aspect, 0.1 + 0.8 * kit_hash(ivec2(i, 8)));
            b = max(b, kit_buf_seed_disc(p, q, 0.03, 0.01));
        }
        b = max(b, kit_buf_seed_noise(ivec2(fragCoord) / 4, 11, 0.01));
    }
    fragColor = vec4(1.0, b, which == 0 ? 0.0 : 1.0, 1.0);
}
