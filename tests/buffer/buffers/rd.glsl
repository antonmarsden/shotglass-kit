// One Gray-Scott step of the state on iChannel0 (rd8's previous state for rd1, the
// buffer before it for rd2..rd8): eight chained buffers give eight steps per film
// frame. The preset is picked by z, which the seed writes: 0 coral, 1 mitosis, and
// the rest for completeness (2 maze, 3 spots, 4 waves). The culture grows only on the
// agar, a disc of radius DISH frame heights in the middle: outside it the state is
// held at A = 1, B = 0, so growth stops at the dish wall.
#include <buffer/sample.glsl>

vec2 preset(float z) {
    int i = int(floor(z + 0.5));
    if (i == 1) return kit_buf_gs_mitosis();
    if (i == 2) return kit_buf_gs_maze();
    if (i == 3) return kit_buf_gs_spots();
    if (i == 4) return kit_buf_gs_waves();
    return kit_buf_gs_coral();
}

const float DISH = 0.42;

vec4 rd_step(sampler2D state, ivec2 p) {
    vec4 s = kit_buf_fetch(state, p, false);
    vec2 q = (vec2(p) + 0.5 - 0.5 * iResolution.xy) / iResolution.y;
    if (length(q) > DISH) return vec4(1.0, 0.0, s.z, 1.0);
    vec4 lap = kit_buf_laplacian(state, p, false);
    return vec4(kit_buf_gray_scott(s.xy, lap.xy, preset(s.z)), s.z, 1.0);
}

// rd1 (params.FIRST defined) also reads @prev on iChannel1: on the reset frame that is
// its init pass (the seed), which it steps instead of rd8's black previous state.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
#ifdef FIRST
    if (iFrame == 0) {
        fragColor = rd_step(iChannel1, p);
        return;
    }
#endif
    fragColor = rd_step(iChannel0, p);
}
