// The test film's music. Every sound-safe kit file (`// sound: yes`) is included here,
// so CI also checks each one as a sound shader: no derivatives, no picture uniforms.
// A quiet drone, a breath of wind, and a soft tick every second.
#include <kit/noise.glsl>
#include <kit/ease.glsl>
#include <kit/color.glsl>
#include <kit/sdf.glsl>

// A sine at a whole-hertz frequency. The phase comes from the sample index with
// integer arithmetic, so it stays exact however long the film is.
float tone(int samp, int hz, int rate) {
    return sin(6.28318531 * float(((samp % rate) * hz) % rate) / float(rate));
}

// White noise in -1..1, a different stream per seed.
float white(int samp, int seed) {
    return float(kit_hash_u(uvec2(uint(samp), uint(seed))) >> 8) / 8388608.0 - 1.0;
}

vec2 mainSound(int samp, float time) {
    int rate = int(iSampleRate);

    // fade in over 4 s, out over the last 2
    float level = kit_ease_smooth(kit_tween(0.0, 4.0, time))
                * (1.0 - kit_ease_linear((time - (MOVIE_DURATION - 2.0)) / 2.0));

    float drone = 0.5 * tone(samp, 110, rate) + 0.3 * tone(samp, 165, rate)
                + 0.15 * tone(samp, 220, rate);

    // wind: slow gusts (fbm) shaping coarse gradient noise, a little wider in stereo
    float gust = kit_fbm(vec3(time * 0.7, 3.0, 5.0), 3);
    vec2 wind = vec2(kit_gradient_noise(vec2(time * 700.0, 0.5)),
                     kit_gradient_noise(vec2(time * 700.0, 9.5))) * gust;

    // tick: a 4 ms noise burst at the start of every second, panned at random
    int second = samp / rate;
    float into = float(samp - second * rate) / iSampleRate;
    float click = white(samp, second) * exp(-into / 0.004);
    float pan = kit_hash(second);

    vec2 s = vec2(drone * 0.12) + wind * 0.08 + click * 0.15 * vec2(1.0 - pan, pan);
    return s * level;
}
