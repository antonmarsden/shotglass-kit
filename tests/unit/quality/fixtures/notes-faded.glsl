// clicks: half-second notes of a 440 Hz sine, each fading in and out over 20 ms.
vec2 mainSound(int samp, float time) {
    float t = float(samp % 24000) / 48000.0;   // time in the note
    float env = smoothstep(0.0, 0.02, t) * smoothstep(0.5, 0.48, t);
    return vec2(0.4 * env * sin(6.28318531 * 440.0 * t));
}
