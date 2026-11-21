// The mix test's mix: every function in sound/mix.glsl and sound/master.glsl, one
// effect a bar (2 s), faded in and out over 0.1 s so switching never clicks:
//   0-2 dry, 2-4 ping-pong delay on the music, 4-6 small room on everything,
//   6-8 hall on the drums (ducked under them), 8-10 stereo width (1 -> 0 -> 2),
//   10-12 music ducked under loud kicks, 12-14 everything three times louder into
//   the limiter, 14-18 delay and hall on the last note, ringing out into silence by 16.4 s.
// The limiter and soft clip are on all the time; they only act when it's loud.
#include <sound/mix.glsl>

// 1 from a to b, fading in and out over 0.1 s.
float on(float t, float a, float b) {
    return smoothstep(a, a + 0.1, t) * (1.0 - smoothstep(b, b + 0.1, t));
}

vec2 mainMix(int samp, float time) {
    int rate = int(iSampleRate);
    float delay_on = on(time, 2.0, 4.0) + on(time, 14.0, 18.0);
    float room_on = on(time, 4.0, 6.0);
    float hall_on = on(time, 6.0, 8.0) + on(time, 14.0, 18.0);
    float duck_on = on(time, 10.0, 12.0);
    float loud = 1.0 + 2.0 * on(time, 12.0, 14.0);

    // music, ducked under the kicks in bar 5 (sidechain)
    vec2 m = kit_mix_read(kit_bus_music, samp);
    m *= mix(1.0, kit_mix_duck(samp, rate, 0.1, 0.5, 0.8), duck_on);
    vec2 o = m + kit_mix_read(kit_bus_sfx, samp);

    // echoes a dotted eighth apart, bouncing left and right
    if (delay_on > 0.0)
        o += 0.45 * delay_on * kit_mix_delay(kit_bus_music, samp, rate, 0.375, 3, 0.5, 1.0);
    if (room_on > 0.0)
        o += 0.35 * room_on * kit_mix_reverb(kit_bus_all, samp, rate, 0.12, 0.08);
    // a long hall on the drums, pushed down while they hit so it blooms after
    if (hall_on > 0.0) {
        float under = kit_duck(kit_mix_level(kit_bus_sfx, samp, rate, 0.0, 0.25), 0.05, 0.3, 0.6);
        o += 0.4 * hall_on * under * kit_mix_reverb(kit_bus_sfx, samp, rate, 0.6, 0.3);
    }

    // width: unchanged, down to mono at 9 s, out to twice as wide at 10 s, back
    float w = time < 8.0 || time >= 10.2 ? 1.0
            : time < 9.0 ? 9.0 - time
            : time < 10.0 ? 2.0 * (time - 9.0)
            : 2.0 - 5.0 * (time - 10.0);
    o = kit_width(o, w);

    // limiter on the dry buses at their current gain, then a soft clip for what the
    // effects add on top
    o *= loud * kit_mix_limit(kit_bus_all, samp, rate, loud, 0.8);
    return kit_soft_clip(o, 0.9);
}
