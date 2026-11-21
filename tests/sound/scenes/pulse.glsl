// A ring that swells on every beat of the music (120 bpm), brighter on each bar's
// first beat: kit_beat is the picture side of the tempo helpers.
#include <sound/tempo.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float beats = kit_beat(iTime, 120.0);
    float hit = exp(-5.0 * fract(beats));
    float downbeat = mod(floor(beats), 4.0) < 0.5 ? 1.0 : 0.5;
    float ring = abs(length(p) - 0.2 - 0.06 * hit) - 0.01;
    float glow = exp(-60.0 * max(ring, 0.0)) * (0.3 + 0.7 * hit * downbeat);
    vec3 col = vec3(0.04, 0.05, 0.08) + glow * vec3(1.0, 0.75, 0.4);
    fragColor = vec4(col, 1.0);
}
