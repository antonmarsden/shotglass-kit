// Incense smoke: the previous density (iChannel0, premultiplied grey) carried along a
// velocity field (kit_buf_advect): rising, plus curl noise that turns once per period
// (kit_curl_noise's angle), so the field, and with it the loop, repeats exactly. New
// smoke from the two tips goes over it (kit_buf_trail_over) and everything fades with
// a half-life; kit_buf_edge_fade of the back-traced point keeps the frame's edges from
// smearing in, and a touch of kit_buf_blur softens it as it rises.
#include <kit/noise.glsl>
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    vec2 p = fragCoord / iResolution.y;
    float turn = 6.28318531 * iMovieTime / MOVIE_DURATION;
    vec2 curl = kit_curl_noise(p * 2.5, ivec2(0), turn);
    // uv per second: rising faster near the tips, wandering more higher up.
    vec2 vel = vec2(0.0, 0.12) + curl * vec2(0.09 / aspect, 0.04) * (0.3 + 1.7 * uv.y);
    vec2 from = kit_buf_advect_uv(uv, vel, iTimeDelta);
    vec4 moved = kit_buf_advect(iChannel0, uv, vel, iTimeDelta, false) * kit_buf_edge_fade(from, 0.01);
    vec4 soft = kit_buf_blur(iChannel0, ivec2(from * iResolution.xy), false) * kit_buf_edge_fade(from, 0.01);
    moved = mix(moved, soft, 0.15);
    vec2 tips[2] = vec2[2](vec2(0.5 * aspect - 0.025, 0.47), vec2(0.5 * aspect + 0.03, 0.43));
    float a = 0.0;
    for (int i = 0; i < 2; i++) {
        a = max(a, 0.9 * kit_buf_seed_disc(p, tips[i] + vec2(0.0, 0.01), 0.007, 0.01));
    }
    vec4 elem = vec4(vec3(a), a);
    fragColor = kit_buf_trail_over(moved, elem, 0.75, iTimeDelta);
}
