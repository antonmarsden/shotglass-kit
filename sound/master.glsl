// shotglass-kit/sound: master.glsl
//
// Per-sample shaping for the end of a mix: stereo width, a ducking gain from a level,
// and a soft clip. Each looks at one sample (or one level) only, so they work in
// `mainMix`, music and shot sounds alike. sound/mix.glsl builds on them with helpers
// that read the mix's buses (delay, reverb, ducking, a limiter).
// Stereo is vec2(left, right), levels and gains are linear amplitude.
// sound: yes

// kit_width(s, width): widen or narrow a stereo sample, by scaling its side
// (left - right) and keeping its mid (left + right).
//   s      a stereo sample
//   width  0 mono, 1 unchanged, 2 twice as wide; clamped to 0..2
//   ->  the same mid, the side times width; mono input stays mono
//   e.g. vec2 o = kit_width(vec2(0.3, 0.1), 1.5);
vec2 kit_width(vec2 s, float width) {
    float m = 0.5 * (s.x + s.y);
    float d = 0.5 * (s.x - s.y) * clamp(width, 0.0, 2.0);
    return vec2(m + d, m - d);
}

// kit_duck(level, lo, hi, depth): a gain that dips as a level rises, to make room
// for one sound under another (music under effects). Smooth (smoothstep) between
// the two thresholds, so the gain never jumps while the level moves smoothly.
//   level  the level that pushes down: sound/mix.glsl's kit_mix_level, or the
//          engine's sfxLevel(samp) in `mainMix`; linear amplitude, 0..
//   lo     level where the dip starts
//   hi     level where it is at its deepest (> lo)
//   depth  how far it dips, 0..1: 0 never, 0.7 to 0.3 times, 1 to silence
//   ->  1 - depth .. 1
//   e.g. float duck = kit_duck(0.25, 0.12, 0.35, 0.7);
float kit_duck(float level, float lo, float hi, float depth) {
    return 1.0 - clamp(depth, 0.0, 1.0) * smoothstep(lo, max(hi, lo + 1e-6), level);
}

// kit_soft_clip(x, ceiling): keep a sample inside +-ceiling without a hard edge.
// Below half the ceiling it changes nothing; above, it bends smoothly (tanh, same
// slope where the bend starts) towards the ceiling, which it never reaches. Odd
// (kit_soft_clip(-x) = -kit_soft_clip(x)), so it adds no DC offset to a signal that
// has none. Clipping adds overtones: keep levels up to the ceiling for safety, and
// use kit_mix_limit (sound/mix.glsl) to bring the loudness down.
//   x        a sample, float or stereo
//   ceiling  the largest output, > 0 (1.0 for full scale, 0.9 for a little headroom)
//   ->  -ceiling .. ceiling (exclusive)
//   e.g. vec2 o = kit_soft_clip(vec2(1.4, -0.2), 0.9);
float kit_soft_clip(float x, float ceiling) {
    float c = max(ceiling, 1e-6);
    float k = 0.5 * c;   // the knee
    float a = abs(x);
    if (a <= k) return x;
    // tanh's argument is clamped: some drivers give NaN for a large one
    float y = k + (c - k) * tanh(min((a - k) / (c - k), 10.0));
    return x < 0.0 ? -y : y;
}
vec2 kit_soft_clip(vec2 s, float ceiling) {
    return vec2(kit_soft_clip(s.x, ceiling), kit_soft_clip(s.y, ceiling));
}
