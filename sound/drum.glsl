// shotglass-kit/sound: drum.glsl
//
// Drums: kick, snare and hi-hat. Like instrument.glsl, each is one function of the
// time since the hit (`t`, seconds; negative gives 0), a frequency and a few
// parameters, returns a level around +-1, and holds no state. Every hit rises from 0
// and ends in true silence at a time the header gives, so hits never click.
//
// The noise in the snare and hat is a function of `t` alone: integer-hashed values
// 24000 times a second, joined by straight lines, so it is the same on every GPU, at
// every sample rate, and varies smoothly with `t` (a tiny timing difference between
// drivers gives a tiny difference in level). Every hit of a drum has the same noise,
// like a sample.
// sound: yes

#include "envelope.glsl"

// lowbias32 integer hash, as core/noise.glsl's kit_hash_u (the sound library doesn't
// depend on core).
uint kit__drum_hash(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352dU;
    x ^= x >> 15;
    x *= 0x846ca68bU;
    x ^= x >> 16;
    return x;
}

// White noise point i (-1..1), exact in float32.
float kit__drum_white(int i, uint seed) {
    return float(kit__drum_hash(uint(i) ^ seed) >> 8) * (2.0 / 16777216.0) - 1.0;
}

// Noise at t: 24000 points a second, joined by straight lines. With `high` it takes the
// difference of neighbouring points instead (high-passed: a brighter hiss). -1..1.
// t is clamped to 0..60 s, far longer than any hit, so the index stays small.
float kit__drum_noise(float t, uint seed, bool high) {
    float x = clamp(t, 0.0, 60.0) * 24000.0;
    float fi = floor(x);
    int i = int(fi);
    float a = kit__drum_white(i, seed), b = kit__drum_white(i + 1, seed);
    if (high) {
        a = 0.5 * (a - kit__drum_white(i - 1, seed));
        b = 0.5 * (b - kit__drum_white(i, seed));
    }
    return mix(a, b, x - fi);
}

// A hit: a smooth rise over `attack` seconds (no corner where it peaks), then
// envelope.glsl's fall, reaching 0 at t = decay.
float kit__drum_hit(float t, float attack, float decay) {
    return smoothstep(0.0, attack, t) * kit_env_ar(t, 0.0, decay);
}

// Two partials at hz * ra and hz * rb, multiplied: tones at their sum and difference.
float kit__drum_sin2(float t, float hz, float ra, float rb) {
    return sin(6.28318531 * fract(ra * hz * t)) * sin(6.28318531 * fract(rb * hz * t));
}

// kit_drum_kick(t, hz, decay): a kick drum: a sine that drops from three times its
// pitch to `hz` in the first few tens of milliseconds, with a short click on the beat.
//   t      seconds since the hit
//   hz     the pitch it settles on, hertz (40..70 for a kick, higher for a tom)
//   decay  seconds until silence (from t = decay); 0.2 tight, 0.6 boomy
//   ->  -1..1; 0 before t = 0 and after the decay
//   cost: a sine, an exp and 2 hashes
//   e.g. float v = kit_drum_kick(since, 50.0, 0.4);
float kit_drum_kick(float t, float hz, float decay) {
    if (t < 0.0 || t >= decay) return 0.0;
    float e = kit__drum_hit(t, 0.002, decay);
    // the pitch glides as hz * (1 + 2 exp(-t / tau)); the phase is its integral
    float tau = 0.03;
    float phase = hz * t + 2.0 * hz * tau * (1.0 - exp(-t / tau));
    float body = sin(6.28318531 * fract(phase));
    float ce = kit__drum_hit(t, 0.001, 0.006);
    float click = kit__drum_noise(t, 0x2545f491U, false);
    return e * (0.85 * body) + 0.15 * ce * click;
}

// kit_drum_snare(t, hz, decay): a snare drum: a short two-tone body (hz and 1.6 hz,
// dropping slightly in pitch) under a burst of noise, the snares.
//   t      seconds since the hit
//   hz     the body's pitch, hertz (150..250)
//   decay  seconds until the noise is silent (from t = decay); the body lasts
//          0.4 of that. 0.15 tight, 0.35 loose
//   ->  -1..1; 0 before t = 0 and after the decay
//   cost: 2 sines, an exp and 2 hashes
//   e.g. float v = kit_drum_snare(since, 190.0, 0.25);
float kit_drum_snare(float t, float hz, float decay) {
    if (t < 0.0 || t >= decay) return 0.0;
    float be = kit__drum_hit(t, 0.002, 0.4 * decay);
    // pitch hz * (1 + 0.3 exp(-t / 0.02)), integrated
    float phase = hz * t + 0.3 * hz * 0.02 * (1.0 - exp(-t / 0.02));
    float body = 0.6 * sin(6.28318531 * fract(phase)) + 0.4 * sin(6.28318531 * fract(1.6 * phase));
    float ne = kit__drum_hit(t, 0.002, decay);
    float noise = kit__drum_noise(t, 0x68e31da4U, false);
    return 0.45 * be * be * body + 0.55 * ne * ne * noise;
}

// kit_drum_hat(t, hz, decay): a hi-hat: high-passed noise with a metallic ring, three
// pairs of inharmonic partials multiplied together (ring modulation), as the classic
// drum machines do with square waves.
//   t      seconds since the hit
//   hz     the lowest metallic partial, hertz (the others are up to 3.9 times higher;
//          1500..3000 suits a hat, lower sounds like a cowbell or a cymbal)
//   decay  seconds until silence (from t = decay): 0.05 closed, 0.3 open
//   ->  -1..1; 0 before t = 0 and after the decay
//   cost: 6 sines and 4 hashes
//   e.g. float v = kit_drum_hat(since, 2000.0, 0.06);
float kit_drum_hat(float t, float hz, float decay) {
    if (t < 0.0 || t >= decay) return 0.0;
    float e = kit__drum_hit(t, 0.001, decay);
    float metal = (kit__drum_sin2(t, hz, 1.0, 1.483)
                 + kit__drum_sin2(t, hz, 1.8, 2.546)
                 + kit__drum_sin2(t, hz, 2.63, 3.897)) / 3.0;
    float noise = kit__drum_noise(t, 0xb5297a4dU, true);
    return e * e * (0.4 * metal + 0.6 * noise);
}
