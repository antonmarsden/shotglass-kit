// shotglass-kit/sound: mix.glsl
//
// Effects for `mainMix`: a multi-tap delay, a reverb made of many short delays, a
// smoothed level for ducking and limiting. They read the engine's two buses through
// music(samp) and sfx(samp), which exist only in a mix shader, so this file can be
// included by `[sound] mix` only (music and shot sounds: use sound/master.glsl).
//
// Every effect here is a sum of reads at fixed distances from `samp`, with no
// feedback: each output sample is computed on its own, the result doesn't depend on
// the chunk size, and nothing can run away. A "feedback" amount is the level of each
// echo relative to the one before, and the echoes stop after the last tap.
//
// How far they read. The engine keeps `[sound] mix_lookback` seconds of each bus
// behind the sample being mixed (default 1.0) and 50 ms ahead; reads outside that
// return silence, but not the same silence for every chunk. So keep every delay,
// reverb size and release below the film's `mix_lookback` (raise it in `movie.toml`
// for longer echoes); each header says how far back its reads go. Look-aheads here
// are clamped to 50 ms.
//
// `bus` picks what to read: kit_bus_music, kit_bus_sfx, or kit_bus_all (both,
// summed). `rate` is the sample rate in hertz, `int(iSampleRate)` (library code reads
// no uniforms). Stereo is vec2(left, right), levels and gains are linear amplitude.
// sound: mix only

#include "master.glsl"

const int kit_bus_music = 0;   // music(samp): the music track
const int kit_bus_sfx = 1;     // sfx(samp): every shot sound, faded for transitions
const int kit_bus_all = 2;     // music(samp) + sfx(samp)

// kit_mix_read(bus, samp): one sample of a bus.
//   bus   kit_bus_music, kit_bus_sfx or kit_bus_all
//   samp  the sample index; within mix_lookback behind and 50 ms ahead of the
//         sample being mixed (see the file header)
//   ->  stereo, as the bus has it
//   e.g. vec2 dry = kit_mix_read(kit_bus_all, samp);
vec2 kit_mix_read(int bus, int samp) {
    if (bus == kit_bus_music) return music(samp);
    if (bus == kit_bus_sfx) return sfx(samp);
    return music(samp) + sfx(samp);
}

// Seconds to a whole number of samples (>= 0).
int kit__mix_samples(float seconds, int rate) {
    return int(floor(max(seconds, 0.0) * float(rate) + 0.5));
}

// kit_mix_delay(bus, samp, rate, time, taps, feedback, pingpong): echoes of a bus,
// `time` apart, each `feedback` times the one before; the first is at full level.
// Only the echoes (the wet signal): add the dry sound yourself.
//   bus       which bus to echo (kit_bus_music, kit_bus_sfx, kit_bus_all)
//   samp      the sample being mixed, as passed to mainMix
//   rate      sample rate, hertz: int(iSampleRate)
//   time      seconds between echoes, > 0 (at least one sample)
//   taps      how many echoes, 1..16
//   feedback  level of each echo relative to the one before, 0..0.99
//   pingpong  0..1: 0 every echo where the sound was, 1 the 1st, 3rd, 5th... swapped
//             left for right, so the echoes bounce between the speakers
//   ->  stereo; at most 1 / (1 - feedback) times the bus's peak
//   reads: up to taps * time seconds back
//   cost: taps bus reads (twice that for kit_bus_all)
//   e.g. vec2 echo = kit_mix_delay(kit_bus_music, samp, int(iSampleRate), 0.31, 3, 0.5, 1.0);
vec2 kit_mix_delay(int bus, int samp, int rate, float time, int taps, float feedback,
                   float pingpong) {
    int d = max(kit__mix_samples(time, rate), 1);
    int n = clamp(taps, 1, 16);
    float fb = clamp(feedback, 0.0, 0.99);
    float pp = clamp(pingpong, 0.0, 1.0);
    vec2 o = vec2(0.0);
    float g = 1.0;
    for (int k = 1; k <= 16; k++) {
        if (k > n) break;
        vec2 v = kit_mix_read(bus, samp - k * d);
        if (k % 2 == 1) v = mix(v, v.yx, pp);
        o += v * g;
        g *= fb;
    }
    return o;
}

// kit_mix_reverb(bus, samp, rate, size, decay): a room, approximated by 24 reflections
// at irregular times up to `size` seconds, fading exponentially to `decay` at the
// last. Later reflections are duller (each is two reads up to 0.25 ms apart,
// averaged) and spread between the speakers in a fixed pattern. Scaled so the wet
// signal is about as loud as the dry one (equal energy). Only the reverb: add the dry
// sound yourself, and mix in 0.1..0.4 of this. No feedback, so the tail ends exactly
// `size` seconds after the sound does; small sizes (0.05..0.15) sound like a room,
// larger ones like a hall with audible echoes.
//   bus    which bus to reverberate (kit_bus_music, kit_bus_sfx, kit_bus_all)
//   samp   the sample being mixed, as passed to mainMix
//   rate   sample rate, hertz: int(iSampleRate)
//   size   seconds to the last reflection, 0.01..mix_lookback
//   decay  level of the last reflection relative to the first, 0.001..1
//          (0.05 a soft room, 0.3 a long ring)
//   ->  stereo, about the bus's loudness
//   reads: up to size + 0.00025 seconds back
//   cost: 48 bus reads (96 for kit_bus_all), 24 pows
//   e.g. vec2 room = kit_mix_reverb(kit_bus_sfx, samp, int(iSampleRate), 0.13, 0.1);
vec2 kit_mix_reverb(int bus, int samp, int rate, float size, float decay) {
    // reflection times as fractions of size: sparse at first, denser later
    const float at[24] = float[24](
        0.1373, 0.2082, 0.2932, 0.3257, 0.3913, 0.4312, 0.4647, 0.5175,
        0.5431, 0.5897, 0.6159, 0.6503, 0.6905, 0.7308, 0.7463, 0.7783,
        0.8157, 0.8502, 0.8707, 0.8944, 0.9318, 0.9409, 0.9812, 1.0);
    float len = max(size, 0.01) * float(rate);
    float dec = clamp(decay, 0.001, 1.0);
    float dull = 0.00025 * float(rate) / 23.0;
    vec2 o = vec2(0.0);
    float energy = 0.0;
    for (int k = 0; k < 24; k++) {
        float g = pow(dec, at[k]);
        int d = int(floor(at[k] * len + 0.5));
        int w = int(floor(dull * float(k) + 0.5));
        vec2 v = 0.5 * (kit_mix_read(bus, samp - d) + kit_mix_read(bus, samp - d - w));
        // 0, 0.618, 0.236, 0.854, ...: how far towards the other speaker
        v = mix(v, v.yx, fract(float(k) * 0.618034));
        o += v * g;
        energy += g * g;
    }
    return o * inversesqrt(energy);
}

// kit_mix_level(bus, samp, rate, attack, release): how loud a bus is around a sample,
// for ducking and limiting. The largest peak (either channel) in a window, each
// weighted by how near it is: a peak `attack` seconds ahead counts for nothing, one
// at samp fully, and one `release` seconds back for nothing again. So the level rises
// in a straight line before a loud sound arrives and falls in a straight line after
// it. It looks at 64 samples spread evenly over the window, on a grid fixed to the
// film (not to samp), so the level moves continuously from one sample to the next:
// a gain made from it never steps or clicks. A peak shorter than the grid's spacing,
// (attack + release) / 63, can fall between its points and read lower.
//   bus      which bus to measure (kit_bus_music, kit_bus_sfx, kit_bus_all)
//   samp     the sample being mixed, as passed to mainMix (>= 0)
//   rate     sample rate, hertz: int(iSampleRate)
//   attack   seconds of look-ahead, 0..0.05 (clamped: the engine gives no more)
//   release  seconds it takes to let go, 0..mix_lookback
//   ->  0.. (linear amplitude)
//   reads: up to release seconds back, attack ahead
//   cost: 64 bus reads (128 for kit_bus_all)
//   e.g. float lvl = kit_mix_level(kit_bus_sfx, samp, int(iSampleRate), 0.01, 0.15);
float kit_mix_level(int bus, int samp, int rate, float attack, float release) {
    int a = kit__mix_samples(clamp(attack, 0.0, 0.05), rate);
    int r = kit__mix_samples(release, rate);
    int step = max((a + r + 62) / 63, 1);   // 64 points cover a + r
    int first = ((samp + a) / step) * step; // the furthest grid point ahead
    float fa = float(max(a, 1)), fr = float(max(r, 1));
    float m = 0.0;
    for (int j = 0; j < 64; j++) {
        int t = first - j * step;
        // weight: 0 at a ahead, 1 at samp, 0 at r back; a point enters and leaves
        // the window at 0, which is what keeps the level continuous
        int d = t - samp;
        float w = d > 0 ? 1.0 - float(d) / fa : 1.0 + float(d) / fr;
        if (w <= 0.0) continue;
        vec2 v = abs(kit_mix_read(bus, t));
        m = max(m, max(v.x, v.y) * w);
    }
    return m;
}

// kit_mix_duck(samp, rate, lo, hi, depth): a gain for "sidechain" ducking: dips as the
// shot sounds get loud, so the music makes room for them. sound/master.glsl's
// kit_duck of the sfx bus's kit_mix_level, with a 10 ms attack (it starts dipping
// just before a hit) and a 0.15 s release. For other times, write
// kit_duck(kit_mix_level(kit_bus_sfx, samp, rate, attack, release), lo, hi, depth).
//   samp   the sample being mixed, as passed to mainMix
//   rate   sample rate, hertz: int(iSampleRate)
//   lo     sfx level where the dip starts (linear amplitude)
//   hi     sfx level where it is deepest (> lo)
//   depth  how far it dips, 0..1: 0.7 takes the music down to 0.3 times
//   ->  1 - depth .. 1; multiply the music by it
//   reads: up to 0.15 s back, 10 ms ahead
//   cost: 64 bus reads
//   e.g. vec2 m = music(samp) * kit_mix_duck(samp, int(iSampleRate), 0.12, 0.35, 0.7);
float kit_mix_duck(int samp, int rate, float lo, float hi, float depth) {
    return kit_duck(kit_mix_level(kit_bus_sfx, samp, rate, 0.01, 0.15), lo, hi, depth);
}

// kit_mix_limit(bus, samp, rate, gain, ceiling): a look-ahead limiter's gain: how much
// to turn the output down so that a bus played at `gain` peaks at `ceiling` at most.
// It starts turning down 5 ms before a loud peak and lets go over 0.2 s, following
// kit_mix_level, so the gain never steps. It measures the dry bus (and can miss a
// peak shorter than 3 ms), not your effects: finish with kit_soft_clip for whatever
// slips past or the echoes and reverb add.
//   bus      the bus your output mostly is (usually kit_bus_all)
//   samp     the sample being mixed, as passed to mainMix
//   rate     sample rate, hertz: int(iSampleRate)
//   gain     how loud the bus is in your output (the gain you apply to it), > 0
//   ceiling  the loudest the output may be, linear amplitude (0.9, say)
//   ->  0..1; 1 while the bus at `gain` stays under the ceiling. Multiply by it
//   reads: up to 0.2 s back, 5 ms ahead
//   cost: 128 bus reads for kit_bus_all, 64 for one bus
//   e.g. vec2 o = kit_soft_clip(2.0 * kit_mix_read(kit_bus_all, samp)
//            * kit_mix_limit(kit_bus_all, samp, int(iSampleRate), 2.0, 0.8), 0.9);
float kit_mix_limit(int bus, int samp, int rate, float gain, float ceiling) {
    float peak = kit_mix_level(bus, samp, rate, 0.005, 0.2) * max(gain, 0.0);
    return peak > ceiling ? max(ceiling, 0.0) / peak : 1.0;
}
