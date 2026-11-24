// Quarter-second notes of a 430 Hz sine with no fade: each starts and is cut mid-wave.
vec2 mainSound(int samp, float time) {
    int rate = int(iSampleRate);
    float t = float(samp % (rate / 4)) / float(rate);   // time in the note
    return vec2(0.4 * sin(6.28318531 * 430.0 * t + 1.0));
}
