// shotglass-kit/core: ease.glsl
//
// The same eases as movie.toml keyframes (`ease = "smooth"` etc.), so a shader can
// shape its own motion exactly like an animated uniform would.
// sound: yes
// Every function clamps x to 0..1 and returns 0..1, with f(0) = 0 and f(1) = 1.
//   cost: a few multiplies
//   e.g.  float s = kit_ease_smooth(iShotProgress);

float kit_ease_linear(float x) { return clamp(x, 0.0, 1.0); }

// smoothstep: gentle start and end ("smooth", the movie.toml default)
float kit_ease_smooth(float x) {
    x = clamp(x, 0.0, 1.0);
    return x * x * (3.0 - 2.0 * x);
}

// smootherstep: flatter start and end, no jolt in acceleration ("smoother")
float kit_ease_smoother(float x) {
    x = clamp(x, 0.0, 1.0);
    // min: the quintic rounds to 1.0000005 just below x = 1 (tests/unit/core/ease.test.glsl)
    return min(x * x * x * (x * (6.0 * x - 15.0) + 10.0), 1.0);
}

// accelerate from rest ("in")
float kit_ease_in(float x) {
    x = clamp(x, 0.0, 1.0);
    return x * x;
}

// decelerate to rest ("out")
float kit_ease_out(float x) {
    x = clamp(x, 0.0, 1.0);
    return 1.0 - (1.0 - x) * (1.0 - x);
}

// accelerate, then decelerate ("inout")
float kit_ease_inout(float x) {
    x = clamp(x, 0.0, 1.0);
    return x < 0.5 ? 2.0 * x * x : 1.0 - 2.0 * (1.0 - x) * (1.0 - x);
}

// hold, then jump at the end ("step"): 0 until x reaches 1
float kit_ease_step(float x) { return x < 1.0 ? 0.0 : 1.0; }

// kit_tween(from, to, t): how far t is from `from` to `to`, as 0..1 (clamped), ready
// to feed to an ease. If to <= from it's a step at `to`.
//   e.g. float s = kit_ease_smooth(kit_tween(2.0, 3.5, iShotTime));
float kit_tween(float from, float to, float t) {
    return to > from ? clamp((t - from) / (to - from), 0.0, 1.0) : (t < to ? 0.0 : 1.0);
}
