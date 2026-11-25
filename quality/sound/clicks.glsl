// shotglass-kit/quality: sound/clicks.glsl
//
// Clicks, for `[[sound.metric]]`: a sample whose jump in slope (the second difference,
// kit_q_slope_jump) stands far above the sound around it, ±WIN samples. Cuts without a
// fade, wrapped phases, hard gates and notes that start or stop mid-wave score high
// wherever they are, shot cuts and a loop film's seam included (the engine wraps a
// loop film's sound). Bright but smooth sound does not, since its neighbours are as
// rough. Measure per sample: the jump over the RMS of the jumps around it (plus FLOOR,
// so near-silence doesn't score on rounding noise), a ratio: a steady sine scores
// about 1.4, a click 10 to hundreds. The report's `max_at` is the time of the worst.
//   params:
//     WIN     number, samples at 48 kHz  how far either side the local level looks
//                                        (default 240: 5 ms; at most 4800)
//     STRIDE  number, samples            look at every STRIDE-th sample (default 8)
//     FLOOR   number, -1..1 amplitude    added to the local level (default 0.001)
//   typical limits: `range = [0, 100]`, `threshold = 20`, max = { max = 20 }.
//   Percussive material (a crackle, a rimshot) can score that on purpose: raise the
//   limit and say why.
//   reads: getSound, ±(WIN + 1) samples
//   cost: (2 WIN / STRIDE + 1) x 3 sound reads per sample
//   e.g.  [[sound.metric]]  use = "quality/sound/clicks"  range = [0, 100]  threshold = 20
//         max = { max = 20 }
// sound: metric only
#include "../ops.glsl"
#ifndef WIN
#define WIN 240.0
#endif
#ifndef STRIDE
#define STRIDE 8.0
#endif
#ifndef FLOOR
#define FLOOR 0.001
#endif

float kit_private_q_jump(int s) { return kit_q_slope_jump(getSound(s - 1), getSound(s), getSound(s + 1)); }

void mainSoundMetric(out float value, in int samp) {
    int w = int(WIN);
    int st = max(int(STRIDE), 1);
    float e = 0.0;
    float n = 0.0;
    for (int k = -w; k <= w; k += st) {
        if (abs(k) < 4) continue;   // leave the click itself and its neighbours out
        float r = kit_private_q_jump(samp + k);
        e += r * r;
        n += 1.0;
    }
    value = kit_private_q_jump(samp) / (sqrt(e / max(n, 1.0)) + FLOOR);
}
