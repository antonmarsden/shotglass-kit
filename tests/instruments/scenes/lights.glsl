// Seven lights, one per instrument in the order the music plays them (pluck, bell,
// electric piano, pad, kick, snare, hat); the one playing glows, and all of them in
// the closing groove. Bars of the music: 120 bpm, 2 s each.
#include <sound/tempo.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float bar = floor(kit_beat(iTime, 120.0) / 4.0);
    // which light each bar shows: bars 3 and 4 are both the pad
    int lit = bar < 3.0 ? int(bar) : bar < 5.0 ? 3 : int(bar) - 1;
    bool all = bar >= 8.0 && bar < 10.0;
    float hit = exp(-6.0 * fract(kit_beat(iTime, 120.0)));
    vec3 col = vec3(0.04, 0.05, 0.08);
    for (int i = 0; i < 7; i++) {
        vec2 c = vec2((float(i) - 3.0) * 0.2, 0.0);
        float on = (all || i == lit) ? 0.4 + 0.6 * hit : 0.08;
        float d = length(p - c) - 0.05;
        col += on * exp(-80.0 * max(d, 0.0)) * vec3(1.0, 0.75, 0.4);
    }
    fragColor = vec4(col, 1.0);
}
