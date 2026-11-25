// shotglass-kit/sound: tempo.glsl
//
// Beats and bars at a tempo. The step functions work from the integer sample index
// (`samp`, as passed to mainSound) with integer arithmetic, so the step a sample falls
// in, and the time since that step began, are exact at any point in a film, however
// long. Feed kit_beat_since straight into an envelope and an oscillator's phase: it
// stays small, so a note sounds the same at 10 minutes as at 10 seconds (a float
// `time` that large would already be audibly coarse).
//
// A "step" is a beat divided into `per_beat` equal parts: 1 counts beats, 2 eighth
// notes, 4 sixteenths, 3 triplets (taking the beat as a quarter note). Step 0 starts
// at sample 0, so in music (movie time) the grid starts with the film; in a shot sound
// it starts at the shot's time 0.
// sound: yes

// Steps per minute, clamped so kit_private_beat_pos stays inside int at rates up to 192 kHz.
int kit_private_beat_den(int bpm, int per_beat) {
    return min(max(bpm, 1) * max(per_beat, 1), 10000);
}

// The step a sample is in, and how far into it, in units of 1 / (60 * rate) of a step.
// With s = whole seconds and r = the samples left over, the position in steps is
// samp * den / (60 * rate) = (s * den) / 60 + r * den / (60 * rate), den = steps per
// minute. Splitting s * den into 60 * a + b keeps every product well inside int.
ivec2 kit_private_beat_pos(int samp, int rate, int bpm, int per_beat) {
    rate = max(rate, 1);
    int den = kit_private_beat_den(bpm, per_beat);
    int minute = 60 * rate;
    int shift = 0;
    if (samp < 0) {   // move up by whole minutes (a whole number of steps), then back
        int k = (-1 - samp) / minute + 1;
        samp += k * minute;
        shift = k * den;
    }
    int s = samp / rate, r = samp - s * rate;
    int sd = s * den;
    int a = sd / 60, b = sd - a * 60;
    int num = b * rate + r * den;   // < rate * (60 + den), under 2^31
    int step = a + num / minute;
    return ivec2(step - shift, num - (num / minute) * minute);
}

// kit_beat_step(samp, rate, bpm, per_beat): the index of the step a sample falls in.
//   samp      sample index, as passed to mainSound; any int (negative: steps before 0)
//   rate      samples per second: int(iSampleRate), up to 192000
//   bpm       beats per minute, >= 1
//   per_beat  steps per beat, >= 1 (1 beats, 2 eighths, 4 sixteenths, 3 triplets);
//             bpm * per_beat is clamped to 10000 (300 bpm in 32nds)
//   ->  step index: 0 from sample 0, counting up (negative before it)
//   cost: a few integer divisions
//   e.g. int beat = kit_beat_step(samp, int(iSampleRate), 120, 1);
//        int six  = kit_beat_step(samp, int(iSampleRate), 120, 4) % 16;   // 16 steps a bar
int kit_beat_step(int samp, int rate, int bpm, int per_beat) {
    return kit_private_beat_pos(samp, rate, bpm, per_beat).x;
}

// kit_beat_since(samp, rate, bpm, per_beat): seconds since the current step began.
// Same parameters as kit_beat_step.
//   ->  seconds, 0 up to one step's length (60 / (bpm * per_beat)), exact to float precision
//   cost: a few integer divisions
//   e.g. float since = kit_beat_since(samp, int(iSampleRate), 120, 2);
//        float v = kit_env_ar(since, 0.002, 0.2);   // a hit on every eighth note
float kit_beat_since(int samp, int rate, int bpm, int per_beat) {
    int into = kit_private_beat_pos(samp, rate, bpm, per_beat).y;   // of 60 * rate per step
    float den = float(kit_private_beat_den(bpm, per_beat));
    return float(into) / (den * float(max(rate, 1)));
}

// kit_beat_bar(step, per_bar): which bar a step is in; kit_beat_in_bar(step, per_bar):
// where in its bar, both correct for negative steps.
//   step     a step (or beat) index, e.g. from kit_beat_step
//   per_bar  steps per bar, >= 1 (4 for beats in 4/4, 16 for its sixteenths)
//   ->  bar index (0 for the first per_bar steps); position 0..per_bar-1
//   e.g. int beat = kit_beat_step(samp, int(iSampleRate), 96, 1);
//        int chord = kit_beat_bar(beat, 4) % 4;       // a four-bar progression
//        bool downbeat = kit_beat_in_bar(beat, 4) == 0;
int kit_beat_bar(int step, int per_bar) {
    per_bar = max(per_bar, 1);
    return step >= 0 ? step / per_bar : -((per_bar - 1 - step) / per_bar);
}
int kit_beat_in_bar(int step, int per_bar) {
    per_bar = max(per_bar, 1);
    return step - kit_beat_bar(step, per_bar) * per_bar;
}

// kit_beat(t, bpm): beats elapsed at a time, as a float. For picture code that moves
// with the music (scenes have no samp), and for rough timing; sound that needs exact
// steps uses kit_beat_step / kit_beat_since.
//   t    seconds (e.g. iTime, or movie time in music)
//   bpm  beats per minute, > 0
//   ->  beats; fract() of it is the position within the beat, 0..1
//   e.g. float pulse = exp(-4.0 * fract(kit_beat(iTime, 120.0)));   // flash on every beat
float kit_beat(float t, float bpm) { return t * bpm / 60.0; }

// kit_beat_seconds(beats, bpm): how long a number of beats lasts, e.g. a note length
// for kit_env_adsr's `held`.
//   beats  a count of beats (0.5 = an eighth note in 4/4)
//   bpm    beats per minute, > 0
//   ->  seconds
//   e.g. float held = kit_beat_seconds(0.75, 120.0);   // 0.375 s, a dotted eighth
float kit_beat_seconds(float beats, float bpm) { return beats * 60.0 / bpm; }
