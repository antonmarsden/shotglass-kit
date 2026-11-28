// Conway's Life on a 64x40 torus (kit_buf_life, kit_buf_neighbours), one generation
// every 4 frames (the state is copied between), seeded at the reset with random cells
// (kit_buf_seed_noise). iFrame counts frames since the reset, so the fold is fixed.
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    if (iFrame == 0) {
        fragColor = vec4(kit_buf_seed_noise(p, 5, 0.33));
        return;
    }
    float alive = kit_buf_fetch(iChannel0, p, true).r;
    if (iFrame % 4 != 0) {
        fragColor = vec4(alive);
        return;
    }
    float n = kit_buf_neighbours(iChannel0, p, true).r;
    fragColor = vec4(kit_buf_life(alive, n));
}
