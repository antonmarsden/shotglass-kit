// shotglass-kit/quality: ops.glsl
//
// The maths of the quality metrics, kept apart from the metric files (which read the
// engine's getFrame / getSound and so can't be unit-tested): colour differences, luma,
// the heatmap ramp and the per-pixel tests the metrics use. Colours are display
// colour (sRGB-encoded, 0..1), as the engine gives a frame; "levels" are 8-bit code
// values (1 level = 1/255).
// sound: yes

// kit_q_diff(a, b): how far apart two colours are, the largest channel difference.
//   a, b  colours, 0..1 per channel
//   ->    0..1 (1/255 is one 8-bit level)
//   e.g.  float d = kit_q_diff(vec3(0.2), vec3(0.25));   // 0.05
float kit_q_diff(vec3 a, vec3 b) {
    vec3 d = abs(a - b);
    return max(d.r, max(d.g, d.b));
}

// kit_q_luma(col): Rec. 709 luma of a display colour (weights on the encoded values).
//   col  display colour, 0..1
//   ->   0..1
//   e.g. float y = kit_q_luma(vec3(1.0, 0.5, 0.0));
float kit_q_luma(vec3 col) { return dot(col, vec3(0.2126, 0.7152, 0.0722)); }

// kit_q_lab(col): CIE L*a*b* (D65 white) of an sRGB display colour.
//   col  display colour, 0..1 (clamped)
//   ->   (L* 0..100, a*, b* about -128..128)
//   cost: 3 pow
//   e.g. vec3 lab = kit_q_lab(vec3(1.0));   // (100, 0, 0)
vec3 kit_q_lab(vec3 col) {
    vec3 c = clamp(col, 0.0, 1.0);
    vec3 lin = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
    vec3 xyz = mat3(0.4124564, 0.2126729, 0.0193339,
                    0.3575761, 0.7151522, 0.1191920,
                    0.1804375, 0.0721750, 0.9503041) * lin;
    xyz /= vec3(0.95047, 1.0, 1.08883);
    vec3 f = mix(xyz * 7.787037 + 16.0 / 116.0, pow(max(xyz, vec3(0.0)), vec3(1.0 / 3.0)),
                 step(0.008856, xyz));
    return vec3(116.0 * f.y - 16.0, 500.0 * (f.x - f.y), 200.0 * (f.y - f.z));
}

// kit_q_delta_e(a, b): CIE76 colour difference ΔE*ab between two display colours: about
// 1 is the smallest difference a viewer sees side by side, 2-3 a near match, 10 plainly
// different, 100 black against white.
//   a, b  display colours, 0..1
//   ->    0..about 260
//   cost: 2 kit_q_lab
//   e.g.  float de = kit_q_delta_e(vec3(0.5), vec3(0.52));   // about 1.6
float kit_q_delta_e(vec3 a, vec3 b) { return length(kit_q_lab(a) - kit_q_lab(b)); }

// kit_q_heat(x): the heatmap ramp the metrics colour with: black, red, yellow, white.
//   x   0..1 (clamped): 0 is fine, 1 is as bad as the heatmap shows
//   ->  display colour
//   e.g. value = vec4(kit_q_heat(d * 8.0), d);
vec3 kit_q_heat(float x) {
    float t = clamp(x, 0.0, 1.0);
    return clamp(vec3(3.0 * t, 3.0 * t - 1.0, 3.0 * t - 2.0), 0.0, 1.0);
}

// kit_q_band(step, before, after, maxstep): 1 if a step between two neighbouring pixels
// is a band edge: a change of 1..maxstep 8-bit levels with flat runs on both sides,
// which is what an undithered smooth gradient looks like.
//   step     the change across the edge, in levels (either sign)
//   before   the largest change between neighbours in the run before the edge, levels
//   after    the same for the run after it, levels
//   maxstep  the largest step that counts, in levels (2 is typical)
//   ->       0 or 1
//   e.g.     float b = kit_q_band(1.0, 0.0, 0.0, 2.0);   // 1
float kit_q_band(float step, float before, float after, float maxstep) {
    float s = abs(step);
    return float(s > 0.5 && s < maxstep + 0.5 && before < 0.5 && after < 0.5);
}

// kit_q_soft(g, gb, ga, lo, hi): 1 if a pixel is in soft shading: its slope and the
// slopes two pixels either side (along the same axis) are all between lo and hi levels
// per pixel. Flat fills (slope 0) and hard or antialiased edges (one steep pixel with
// flat ones beside it) are not soft.
//   g        the slope at the pixel, in levels per pixel (either sign)
//   gb, ga   the slopes two pixels before and after it
//   lo, hi   the band of slopes that counts as soft, in levels per pixel
//   ->       0 or 1
//   e.g.     float s = kit_q_soft(2.0, 2.0, 2.0, 0.75, 16.0);   // 1
float kit_q_soft(float g, float gb, float ga, float lo, float hi) {
    vec3 a = abs(vec3(g, gb, ga));
    return float(all(greaterThanEqual(a, vec3(lo))) && all(lessThanEqual(a, vec3(hi))));
}

// kit_q_on_step(frame, step, offset): whether a film frame is one on which a picture
// animated on step (2 = on twos) may change: frames offset, offset + step, ...
//   frame   the film frame index, iFrame
//   step    1 = ones, 2 = twos, 3 = threes (below 1 counts as 1)
//   offset  the first frame of the cadence, in frames (the cadence runs both ways
//           from it, so frames before offset are fine too)
//   ->      true on a step frame
//   e.g.    bool fresh = kit_q_on_step(iFrame, 2, 0);
bool kit_q_on_step(int frame, int step, int offset) {
    int s = max(step, 1);
    int k = abs(frame - offset) % s;   // % of a negative int is undefined in GLSL
    return k == 0;
}

// kit_q_slope_jump(a, b, c): the jump in slope at sample b, from three consecutive
// stereo samples a, b, c: the second difference, the larger channel. A smooth wave
// gives about amplitude x (2 pi hz / rate)^2; a step or a kink gives its own size.
//   a, b, c  consecutive samples, -1..1 per channel
//   ->       0..4
//   e.g.     float j = kit_q_slope_jump(vec2(0.0), vec2(0.0), vec2(1.0));   // 1
float kit_q_slope_jump(vec2 a, vec2 b, vec2 c) {
    vec2 d = abs(a - 2.0 * b + c);
    return max(d.x, d.y);
}
