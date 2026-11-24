// Half-second notes of a 440 Hz sine, each fading in and out over 20 ms: no clicks.
vec2 mainSound(int samp, float time) {
    int rate = int(iSampleRate);
    float t = float(samp % (rate / 2)) / float(rate);   // time in the note
    float env = smoothstep(0.0, 0.02, t) * smoothstep(0.5, 0.48, t);
    return vec2(0.4 * env * sin(6.28318531 * 440.0 * t));
}
