// shotglass-kit/sound: envelope.glsl
//
// Envelopes: how loud a note is at a time since it started. Each takes `t`, seconds
// since the note began (negative: not started yet, gives 0), and returns a level in
// 0..1 to multiply a voice by. They hold no state, so any sample can be computed on
// its own. Attacks rise in a straight line; decays and releases fall along
// (1 - x)^2, which sounds close to an exponential fade but reaches its target
// exactly, so a note ends in true silence at a known time.
// sound: yes

float kit__env_fall(float x) {
    x = 1.0 - clamp(x, 0.0, 1.0);
    return x * x;
}

// kit_env_ar(t, attack, release): rise, then fall straight away. Plucks, hits, blips.
//   t        seconds since the note began
//   attack   seconds to reach 1 (0 for an instant start)
//   release  seconds to fall from 1 to 0 after the attack (0 cuts off)
//   ->  0..1; 0 before t = 0 and from t = attack + release on
//   e.g. float v = kit_env_ar(since, 0.005, 0.3) * sin(6.28318531 * 440.0 * since);
float kit_env_ar(float t, float attack, float release) {
    if (t < 0.0) return 0.0;
    if (t < attack) return t / attack;
    return kit__env_fall((t - attack) / max(release, 1e-6));
}

// Level of an ADSR while the key is held (no release yet).
float kit__env_ads(float t, float attack, float decay, float sustain) {
    if (t < attack) return t / attack;
    return sustain + (1.0 - sustain) * kit__env_fall((t - attack) / max(decay, 1e-6));
}

// kit_env_adsr(t, held, attack, decay, sustain, release): the classic synth envelope.
// Rises to 1, decays to the sustain level while the key is held, and releases to 0
// from wherever it is when the key lets go (even mid-attack), with no jump.
//   t        seconds since the note began
//   held     seconds the key is held (the note's length); release starts there
//   attack   seconds to reach 1 (0 for an instant start)
//   decay    seconds to fall from 1 to sustain
//   sustain  level while held, 0..1
//   release  seconds to fall to 0 after the key lets go
//   ->  0..1; 0 before t = 0 and from t = held + release on
//   e.g. float v = kit_env_adsr(since, 0.4, 0.01, 0.15, 0.6, 0.3);
float kit_env_adsr(float t, float held, float attack, float decay, float sustain, float release) {
    if (t < 0.0) return 0.0;
    sustain = clamp(sustain, 0.0, 1.0);
    held = max(held, 0.0);
    if (t < held) return kit__env_ads(t, attack, decay, sustain);
    return kit__env_ads(held, attack, decay, sustain)
         * kit__env_fall((t - held) / max(release, 1e-6));
}
