// Eight lights, one per bar of the mix test (2 s each at 120 bpm): dry, delay, room,
// hall, width, ducking, limiter, ring-out (14-18 s). The one whose effect is on glows.
#include <sound/tempo.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    int lit = min(int(floor(kit_beat(iTime, 120.0) / 4.0)), 7);
    float hit = exp(-6.0 * fract(kit_beat(iTime, 120.0)));
    vec3 col = vec3(0.04, 0.05, 0.08);
    for (int i = 0; i < 8; i++) {
        vec2 c = vec2((float(i) - 3.5) * 0.18, 0.0);
        float on = i == lit ? 0.4 + 0.6 * hit : 0.08;
        float d = length(p - c) - 0.05;
        col += on * exp(-80.0 * max(d, 0.0)) * vec3(0.5, 0.8, 1.0);
    }
    fragColor = vec4(col, 1.0);
}
