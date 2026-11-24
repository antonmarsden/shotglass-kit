// clicks: quarter-second notes of a 430 Hz sine with no fade: each starts and stops mid-wave.
vec2 mainSound(int samp, float time) {
    float t = float(samp % 12000) / 48000.0;   // time in the note
    return vec2(0.4 * sin(6.28318531 * 430.0 * t + 1.0));
}
