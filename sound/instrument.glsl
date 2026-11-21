// shotglass-kit/sound: instrument.glsl
//
// Pitched instruments: a plucked string, an FM bell, an FM electric piano and a pad.
// Each is one function of the time since the note began (`t`, seconds; negative gives
// 0), its frequency (`hz`) and a few parameters, and returns a level around +-1 for the
// caller to scale. They hold no state, so a note is the same whenever and in whatever
// order its samples are computed: play several at once by adding calls, and keep
// calling a note's function after the next note starts so its tail doesn't cut off.
// Every note starts from 0 (a short attack) and ends in true silence at a time the
// header gives, so notes never click in or out.
//
// Oscillator phases are fract(hz * t) with `t` the small time since the note began
// (see tempo.glsl's kit_beat_since), never a long film time. Partials above about
// 10 kHz fade out and stop at 16 kHz; the library doesn't know the sample rate, so at
// low rates (an 8 kHz render) high notes alias.
// sound: yes

#include "envelope.glsl"

// sin of a whole number of turns plus a fraction, from the fractional part only.
float kit__inst_sin(float turns) { return sin(6.28318531 * fract(turns)); }

// A hit: a smooth rise over `attack` seconds (no corner where it peaks), then
// envelope.glsl's fall, reaching 0 at t = decay.
float kit__inst_hit(float t, float attack, float decay) {
    return smoothstep(0.0, attack, t) * kit_env_ar(t, 0.0, decay);
}

// How much of a partial at `hz` to keep: 1 up to 10 kHz, 0 from 16 kHz.
float kit__inst_band(float hz) { return 1.0 - smoothstep(10000.0, 16000.0, hz); }

// kit_inst_pluck(t, hz, decay, bright): a plucked string, additive (12 partials). Like
// Karplus-Strong without the delay line: higher partials die away sooner, and are
// very slightly sharp, as on a real string.
//   t       seconds since the note began
//   hz      the note's frequency, hertz
//   decay   seconds the fundamental rings for (it is silent from t = decay)
//   bright  0..1: 0 is a soft, dull pluck (partials fall as 1/k^2), 1 a bright,
//           metallic one (1/k^0.8, and the upper partials ring longer)
//   ->  about +-0.7 at the attack, then fading; 0 before t = 0 and after the decay
//   cost: 12 sines
//   e.g. float v = kit_inst_pluck(since, kit_note_hz(64), 1.2, 0.6);
float kit_inst_pluck(float t, float hz, float decay, float bright) {
    if (t < 0.0 || t >= decay) return 0.0;
    bright = clamp(bright, 0.0, 1.0);
    float slope = 2.0 - 1.2 * bright;      // spectrum falls as 1/k^slope
    float damp = 1.5 - bright;             // how much faster each partial dies
    float s = 0.0, total = 0.0;
    for (int i = 1; i <= 12; i++) {
        float k = float(i);
        float f = k * hz * sqrt(1.0 + 0.00008 * k * k);   // slight inharmonicity
        float a = pow(k, -slope) * kit__inst_band(f);
        float e = kit__inst_hit(t, 0.003, decay / (1.0 + damp * (k - 1.0)));
        s += a * e * e * kit__inst_sin(f * t);
        total += a;
    }
    return s / max(total, 1e-6);
}

// kit_inst_bell(t, hz, decay, index): a bell, by frequency modulation: a modulator at
// 1.4 times the carrier gives inharmonic, bell-like partials, and the modulation fades
// with the note, so the strike is bright and the tail a pure tone.
//   t      seconds since the note began
//   hz     the strike pitch (the carrier), hertz
//   decay  seconds until silence (from t = decay)
//   index  modulation depth at the strike, 0..10: 0 a sine, 2..4 a bell, higher is clangier
//   ->  -1..1; 0 before t = 0 and after the decay
//   cost: 2 sines
//   e.g. float v = kit_inst_bell(since, kit_note_hz(76), 2.5, 3.0);
float kit_inst_bell(float t, float hz, float decay, float index) {
    if (t < 0.0 || t >= decay) return 0.0;
    float e = kit__inst_hit(t, 0.002, decay);
    float amp = e * e;
    index = clamp(index, 0.0, 10.0);
    // the sidebands reach about hz * (1 + 1.4 * index): fade the modulation for high notes
    float fm = index * amp * kit__inst_band(hz * (1.0 + 1.4 * index)) * kit__inst_sin(1.4 * hz * t);
    return amp * sin(6.28318531 * fract(hz * t) + fm);
}

// kit_inst_epiano(t, hz, held, bright): an electric piano, by frequency modulation at
// 1:1 (a bright attack that mellows as the note sounds) plus a short metallic "tine"
// at 14 times the pitch. The note fades on its own while held and releases in 0.25 s
// when the key lets go.
//   t       seconds since the note began
//   hz      the note's frequency, hertz
//   held    seconds the key is held; silent from t = held + 0.25
//   bright  0..1: how hard the key is struck (0 mellow, 1 a bark with a strong tine)
//   ->  -1..1; 0 before t = 0 and after the release
//   cost: 3 sines
//   e.g. float v = kit_inst_epiano(since, kit_note_hz(60), 0.8, 0.5);
float kit_inst_epiano(float t, float hz, float held, float bright) {
    held = max(held, 0.0);
    if (t < 0.0 || t > held + 0.25) return 0.0;
    bright = clamp(bright, 0.0, 1.0);
    float amp = smoothstep(0.0, 0.003, t) * kit_env_adsr(t, held, 0.0, 2.5, 0.15, 0.25);
    float index = bright * (0.3 + 1.5 * kit_env_ar(t, 0.0, 0.6));
    float x = 6.28318531 * fract(hz * t);
    float body = sin(x + index * sin(x));
    float te = kit__inst_hit(t, 0.002, 0.08);
    float tine = 0.3 * bright * te * te * kit__inst_sin(14.0 * hz * t) * kit__inst_band(14.0 * hz);
    return amp * (body + tine) / (1.0 + 0.3 * bright);
}

// kit_inst_pad(t, hz, held, attack, release): a soft pad: three slightly detuned
// sawtooth-like voices (6 partials each, 10 cents apart) that drift against each
// other, with a slow swell. Overlap pad notes to play chords.
//   t        seconds since the note began
//   hz       the note's frequency, hertz
//   held     seconds the key is held; release starts there
//   attack   seconds to swell to full level, at least 0.005 (0.2..2 suits a pad)
//   release  seconds to fade after the key lets go, at least 0.005; silent from
//            t = held + release
//   ->  -1..1, mostly within +-0.5; 0 before t = 0 and after the release
//   cost: 18 sines
//   e.g. float v = kit_inst_pad(since, kit_note_hz(57), 3.0, 0.6, 1.5);
float kit_inst_pad(float t, float hz, float held, float attack, float release) {
    held = max(held, 0.0);
    attack = max(attack, 0.005);
    release = max(release, 0.005);
    if (t < 0.0 || t > held + release) return 0.0;
    float amp = kit_env_adsr(t, held, attack, 0.5, 0.8, release);
    float s = 0.0, total = 0.0;
    for (int v = 0; v < 3; v++) {
        float detune = exp2(float(v - 1) * 10.0 / 1200.0);   // -10, 0, +10 cents
        float offset = 0.31 * float(v);                       // voices start out of phase
        for (int i = 1; i <= 6; i++) {
            float k = float(i);
            float a = kit__inst_band(k * hz * detune) / k;
            s += a * kit__inst_sin(k * (hz * detune * t + offset));
            total += a;
        }
    }
    return amp * s / max(total, 1e-6);
}
