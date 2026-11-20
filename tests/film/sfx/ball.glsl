// The bouncing ball in scenes/toys.glsl: a soft thud each time it lands.
// `time` is shot-local, the same clock as the scene's iTime, so the landings line up
// exactly: the scene's bounce is fract(iTime * 0.8), on the table at every whole cycle.
#include <kit/noise.glsl>

const float BOUNCES_PER_SECOND = 0.8;   // keep equal to bounce() in scenes/toys.glsl

// White noise in -1..1, a different stream per seed.
float white(int samp, int seed) {
    return float(kit_hash_u(uvec2(uint(samp), uint(seed))) >> 8) / 8388608.0 - 1.0;
}

vec2 mainSound(int samp, float time) {
    if (time < 0.0) return vec2(0.0);
    float cycles = time * BOUNCES_PER_SECOND;
    int landing = int(floor(cycles));
    float since = fract(cycles) / BOUNCES_PER_SECOND;   // seconds since it hit the table

    // a body that drops in pitch as it settles, plus a short slap of noise
    float vary = 0.9 + 0.2 * kit_hash(landing);
    float pitch = 70.0 * vary + 90.0 * exp(-since / 0.015);
    float phase = since * pitch;   // small: since is under 1.25 s
    float body = sin(6.28318531 * phase) * exp(-since / 0.07);
    float slap = white(samp, landing) * exp(-since / 0.006);
    float thud = 0.5 * body + 0.25 * slap;

    // the ball sits left of centre
    return thud * vec2(0.65, 0.4);
}
