// shotglass-kit/core: animate.glsl
//
// Cartoon animation: eases that overshoot (back), wobble (elastic) or bounce; squash
// and stretch that keeps a shape's area (2D) or volume (3D); a wind-up before a move
// and a settle after it; held keyed poses; and animating on twos or threes. Pure
// arithmetic of their arguments, so they work in scenes, transitions and sound alike.
// The eases live here rather than in ease.glsl because they leave 0..1 and have no
// movie.toml equivalent; like those, they clamp x to 0..1 and give f(0) = 0 and
// f(1) = 1 exactly, but back and elastic go outside 0..1 in between (bounce doesn't).
// sound: yes

// kit_tween and kit_ease_smooth come from ease.glsl
#include "ease.glsl"

// --- Eases -----------------------------------------------------------------------

// kit__back_in(x, s): the cubic behind the back eases; x already clamped.
float kit__back_in(float x, float s) { return x * x * ((s + 1.0) * x - s); }

// kit_ease_back_in(x), kit_ease_back_in(x, s): pull back below 0 first, then
// accelerate to 1 (a wind-up built into the ease).
//   x   progress, 0..1 (clamped)
//   s   how far back, >= 0: 1.70158 (the default) dips 10% of the move, 0 is a plain
//       cubic ease in, 2.59 dips 20%
//   ->  about -0.1..1 with the default; 0 at x = 0, 1 at x = 1
//   e.g. float y = mix(a, b, kit_ease_back_in(kit_tween(1.0, 1.5, iShotTime)));
float kit_ease_back_in(float x, float s) {
    return kit__back_in(clamp(x, 0.0, 1.0), max(s, 0.0));
}
float kit_ease_back_in(float x) { return kit_ease_back_in(x, 1.70158); }

// kit_ease_back_out(x), kit_ease_back_out(x, s): decelerate past 1, then come back
// to it (an overshoot). The mirror of kit_ease_back_in.
//   x   progress, 0..1 (clamped)
//   s   how far past, >= 0: 1.70158 (the default) overshoots by 10% of the move
//   ->  0..about 1.1 with the default; 0 at x = 0, 1 at x = 1
//   e.g. float y = mix(a, b, kit_ease_back_out(iShotProgress, 2.5));
float kit_ease_back_out(float x, float s) {
    return 1.0 - kit__back_in(1.0 - clamp(x, 0.0, 1.0), max(s, 0.0));
}
float kit_ease_back_out(float x) { return kit_ease_back_out(x, 1.70158); }

// kit_ease_back_inout(x), kit_ease_back_inout(x, s): dip back at the start and
// overshoot at the end, by the same amount (s is scaled by 1.525 inside so the
// default dips and overshoots 10% of the move, like the in and out versions).
//   x   progress, 0..1 (clamped)
//   s   how far, >= 0 (default 1.70158)
//   ->  about -0.1..1.1 with the default; 0 at x = 0, 0.5 at x = 0.5, 1 at x = 1
//   e.g. float y = mix(a, b, kit_ease_back_inout(iShotProgress));
float kit_ease_back_inout(float x, float s) {
    x = clamp(x, 0.0, 1.0);
    s = max(s, 0.0) * 1.525;
    return x < 0.5 ? 0.5 * kit__back_in(2.0 * x, s)
                   : 1.0 - 0.5 * kit__back_in(2.0 - 2.0 * x, s);
}
float kit_ease_back_inout(float x) { return kit_ease_back_inout(x, 1.70158); }

// kit_ease_elastic_out(x), kit_ease_elastic_out(x, cycles): shoot to 1 and wobble
// around it like a spring, the wobble dying away to exactly 1 at x = 1.
//   x       progress, 0..1 (clamped)
//   cycles  wobbles over the ease, > 0 (default 3); the swings shrink by half every
//           tenth of the ease
//   ->  0..about 1.3 with the default (the first swing past 1 is the biggest); 0 at
//       x = 0, 1 at x = 1
//   cost: an exp2 and a cos
//   e.g. float sz = kit_ease_elastic_out(kit_tween(0.5, 1.5, iShotTime), 4.0);
float kit_ease_elastic_out(float x, float cycles) {
    x = clamp(x, 0.0, 1.0);
    // 2^-10x, shifted and rescaled to fall from exactly 1 to exactly 0
    float decay = (exp2(-10.0 * x) - 0.0009765625) / 0.9990234375;
    return 1.0 - decay * cos(6.28318531 * cycles * x);
}
float kit_ease_elastic_out(float x) { return kit_ease_elastic_out(x, 3.0); }

// kit_ease_elastic_in(x), kit_ease_elastic_in(x, cycles): wobble around 0, growing,
// then snap to 1. The mirror of kit_ease_elastic_out.
//   x       progress, 0..1 (clamped)
//   cycles  wobbles over the ease, > 0 (default 3)
//   ->  about -0.3..1 with the default; 0 at x = 0, 1 at x = 1
//   cost: an exp2 and a cos
//   e.g. float y = kit_ease_elastic_in(iShotProgress);
float kit_ease_elastic_in(float x, float cycles) {
    return 1.0 - kit_ease_elastic_out(1.0 - clamp(x, 0.0, 1.0), cycles);
}
float kit_ease_elastic_in(float x) { return kit_ease_elastic_in(x, 3.0); }

// kit_ease_elastic_inout(x), kit_ease_elastic_inout(x, cycles): elastic in for the
// first half, elastic out for the second; cycles is per half.
//   x       progress, 0..1 (clamped)
//   cycles  wobbles in each half, > 0 (default 3)
//   ->  about -0.16..1.16 with the default; 0 at x = 0, 0.5 at x = 0.5, 1 at x = 1
//   cost: an exp2 and a cos
//   e.g. float y = kit_ease_elastic_inout(iShotProgress, 2.0);
float kit_ease_elastic_inout(float x, float cycles) {
    x = clamp(x, 0.0, 1.0);
    return x < 0.5 ? 0.5 * kit_ease_elastic_in(2.0 * x, cycles)
                   : 0.5 + 0.5 * kit_ease_elastic_out(2.0 * x - 1.0, cycles);
}
float kit_ease_elastic_inout(float x) { return kit_ease_elastic_inout(x, 3.0); }

// kit_ease_bounce_out(x): fall to 1 and bounce off it three times, each bounce
// lower, coming to rest at x = 1 (a dropped ball; 1 is the floor).
//   x   progress, 0..1 (clamped)
//   ->  0..1; 0 at x = 0, 1 at x = 1 and at each landing (x = 0.364, 0.727, 0.909)
//   e.g. float h = 1.0 - kit_ease_bounce_out(iShotProgress);   // height above the floor
float kit_ease_bounce_out(float x) {
    x = clamp(x, 0.0, 1.0);
    if (x >= 1.0) return 1.0;
    const float n = 7.5625;            // 1 / (1 / 2.75)^2: the first fall lands at 1
    if (x < 1.0 / 2.75) return n * x * x;
    if (x < 2.0 / 2.75) { x -= 1.5 / 2.75;   return n * x * x + 0.75; }
    if (x < 2.5 / 2.75) { x -= 2.25 / 2.75;  return n * x * x + 0.9375; }
    x -= 2.625 / 2.75;
    return n * x * x + 0.984375;
}

// kit_ease_bounce_in(x): the bounces first, growing, then the leap to 1 (the bounce
// out curve played backwards and upside down).
//   x   progress, 0..1 (clamped)
//   ->  0..1; 0 at x = 0, 1 at x = 1
//   e.g. float y = kit_ease_bounce_in(iShotProgress);
float kit_ease_bounce_in(float x) { return 1.0 - kit_ease_bounce_out(1.0 - clamp(x, 0.0, 1.0)); }

// kit_ease_bounce_inout(x): bounce in over the first half, bounce out over the second.
//   x   progress, 0..1 (clamped)
//   ->  0..1; 0 at x = 0, 0.5 at x = 0.5, 1 at x = 1
//   e.g. float y = kit_ease_bounce_inout(iShotProgress);
float kit_ease_bounce_inout(float x) {
    x = clamp(x, 0.0, 1.0);
    return x < 0.5 ? 0.5 * kit_ease_bounce_in(2.0 * x)
                   : 0.5 + 0.5 * kit_ease_bounce_out(2.0 * x - 1.0);
}

// --- Squash and stretch ------------------------------------------------------------

// kit_squash(p, axis, s): squash or stretch a shape along an axis, keeping its area
// (vec2) or volume (vec3). Takes the position you'd give the shape's SDF and returns
// the position to give it instead; the shape grows by s along the axis and shrinks
// by 1/s (2D) or 1/sqrt(s) (3D) across it, about the origin of p, so subtract the
// point it should squash towards first (the contact point on the floor, say). The
// distance you get back is stretched too: multiply it by min(s, 1.0 / s) (2D) or
// min(s, inversesqrt(s)) (3D) for a distance that never overshoots (raymarching,
// shadows); for a 2D fill with a one-pixel edge it doesn't matter.
//   p     position, relative to the squash centre, in the shape's units
//   axis  the direction to stretch along, any length (normalised inside; a zero
//         axis leaves p alone)
//   s     stretch factor, > 0: 1 leaves the shape alone, 1.5 is half as long again
//         along the axis and thinner across, 0.6 squashes it flat and wide
//         (clamped to 0.05..20)
//   ->    the position to feed the shape's SDF
//   e.g. float d = kit_sd_circle(kit_squash(p - floorPt, vec2(0.0, 1.0), 0.7) - vec2(0.0, r), r);
vec2 kit_squash(vec2 p, vec2 axis, float s) {
    float len = length(axis);
    if (len < 1e-12) return p;
    vec2 a = axis / len;
    s = clamp(s, 0.05, 20.0);
    float along = dot(p, a);
    vec2 across = p - along * a;
    return a * (along / s) + across * s;
}
vec3 kit_squash(vec3 p, vec3 axis, float s) {
    float len = length(axis);
    if (len < 1e-12) return p;
    vec3 a = axis / len;
    s = clamp(s, 0.05, 20.0);
    float along = dot(p, a);
    vec3 across = p - along * a;
    return a * (along / s) + across * sqrt(s);
}

// kit_stretch_speed(speed, k): how much to stretch a shape that moves at `speed`,
// for kit_squash along its direction of travel. Grows with speed, then levels off
// so a fast shape never stretches past twice its length.
//   speed  how fast it's moving, in its own units per second (the sign is ignored)
//   k      seconds per unit of speed, >= 0: at speed 1/k it stretches 1.5x
//   ->     1..2 (1 at rest)
//   e.g. float s = kit_stretch_speed(vy, 0.4); vec2 q = kit_squash(p - c, vec2(0.0, 1.0), s);
float kit_stretch_speed(float speed, float k) {
    float v = abs(speed) * max(k, 0.0);
    return 1.0 + v / (1.0 + v);
}

// kit_squash_impact(amount): how much to squash a shape that hits something with
// strength `amount`, for kit_squash along the direction of the hit.
//   amount  0..1 (clamped): 0 no squash, 1 half as tall and (in 2D) twice as wide
//   ->      1..0.5
//   e.g. float s = kit_squash_impact(0.6 * (1.0 - kit_ease_out(kit_tween(0.0, 0.15, sinceHit))));
float kit_squash_impact(float amount) { return 1.0 - 0.5 * clamp(amount, 0.0, 1.0); }

// --- Anticipation and follow-through ---------------------------------------------------

// kit_anticipate(x, amount, windup): progress through a move with a wind-up first:
// it eases back by `amount` (a hold at the far end of the wind-up, where it stops),
// then eases all the way forward to 1. Feed it to mix(from, to, ...).
//   x       progress through the whole thing, wind-up included, 0..1 (clamped)
//   amount  how far back, as a fraction of the move, >= 0 (0.15 is a clear wind-up)
//   windup  the part of the time spent winding up, 0..0.95 (clamped; 0.3 is
//           typical); 0 is no wind-up, a plain smoothstep move
//   ->      -amount..1; 0 at x = 0, -amount at x = windup, 1 at x = 1
//   e.g. float y = mix(y0, y1, kit_anticipate(kit_tween(0.5, 1.4, iShotTime), 0.2, 0.35));
float kit_anticipate(float x, float amount, float windup) {
    x = clamp(x, 0.0, 1.0);
    windup = clamp(windup, 0.0, 0.95);
    amount = windup > 0.0 ? max(amount, 0.0) : 0.0;
    if (x < windup) return -amount * kit_ease_smooth(x / windup);
    return mix(-amount, 1.0, kit_ease_smooth((x - windup) / (1.0 - windup)));
}

// kit_settle(x, amount, wobbles): the wobble about a pose after arriving at it
// (follow-through): it carries on past the pose by about `amount`, swings back, and
// dies away to exactly nothing. Add it to the arrived value, scaled by the move.
//   x        progress through the settle, 0..1 (clamped): 0 the moment of arrival,
//            1 at rest
//   amount   size of the first swing, as a fraction of the move (0.1 is gentle);
//            negative swings the other way first
//   wobbles  how many times it swings to and fro, > 0 (1.5 to 3 is typical)
//   ->       about -amount..amount; 0 at x = 0 and at x = 1, moving forward at x = 0
//   cost: a sin
//   e.g. float y = y1 + (y1 - y0) * kit_settle(kit_tween(1.4, 2.2, iShotTime), 0.12, 2.0);
float kit_settle(float x, float amount, float wobbles) {
    x = clamp(x, 0.0, 1.0);
    float fade = (1.0 - x) * (1.0 - x) * (1.0 - x);
    // 1.5 makes the first swing within about 10% of `amount` for 1.5 to 3 wobbles
    return amount * 1.5 * fade * sin(6.28318531 * wobbles * x);
}

// --- Keyed poses ---------------------------------------------------------------

// kit_keys(t, times, count, hold): where t is in a list of key times: each key's value
// is held for `hold` seconds after the key, then moves to the next key's value,
// arriving on the next key's time. Ease the returned progress however you like
// (kit_pose does it with smoothstep).
//   t      time, in the same seconds as the key times (iShotTime, say)
//   times  key times in seconds, increasing; up to 8, entries past `count` ignored
//   count  how many keys are used, 1..8 (clamped)
//   hold   seconds to hold each key before moving on, >= 0; a hold longer than the
//          gap to the next key makes that move a cut on the next key
//   ->     vec2(i, x): the move is from key i to key i + 1 (i = 0..count-2, as a
//          float), x its raw progress 0..1 (0 while holding). Before the first key
//          (0, 0); after the last, (count - 2, 1), or (0, 0) with one key
//   cost: a loop over the keys
//   e.g. vec2 k = kit_keys(iShotTime, float[8](0.0, 1.0, 2.0, 3.0, 0.0, 0.0, 0.0, 0.0), 4, 0.3);
vec2 kit_keys(float t, float times[8], int count, float hold) {
    int n = clamp(count, 1, 8);
    if (n < 2) return vec2(0.0);
    hold = max(hold, 0.0);
    int i = 0;
    for (int j = 1; j < n - 1; j++) {
        if (t >= times[j]) i = j;
    }
    float start = min(times[i] + hold, times[i + 1]);
    return vec2(float(i), kit_tween(start, times[i + 1], t));
}

// kit_pose(t, times, values, count, hold): keyed poses with holds: the value at
// time t, holding each key's value for `hold` seconds and then easing (smoothstep)
// to the next, arriving on its key time. Overloads for float, vec2 and vec3 values.
//   t       time, in the same seconds as the key times
//   times   key times in seconds, increasing; up to 8 (see kit_keys)
//   values  the value at each key; entries past `count` ignored
//   count   how many keys are used, 1..8 (clamped)
//   hold    seconds to hold each key before moving on, >= 0
//   ->      values[0] before the first key, values[count - 1] after the last
//   cost: a loop over the keys
//   e.g. vec2 c = kit_pose(iShotTime, float[8](0.0, 1.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0),
//                          vec2[8](vec2(0.0), vec2(0.3, 0.1), vec2(-0.2, 0.0), vec2(0.0),
//                                  vec2(0.0), vec2(0.0), vec2(0.0), vec2(0.0)), 3, 0.25);
float kit_pose(float t, float times[8], float values[8], int count, float hold) {
    vec2 k = kit_keys(t, times, count, hold);
    int i = int(k.x);
    int j = min(i + 1, clamp(count, 1, 8) - 1);
    return mix(values[i], values[j], kit_ease_smooth(k.y));
}
vec2 kit_pose(float t, float times[8], vec2 values[8], int count, float hold) {
    vec2 k = kit_keys(t, times, count, hold);
    int i = int(k.x);
    int j = min(i + 1, clamp(count, 1, 8) - 1);
    return mix(values[i], values[j], kit_ease_smooth(k.y));
}
vec3 kit_pose(float t, float times[8], vec3 values[8], int count, float hold) {
    vec2 k = kit_keys(t, times, count, hold);
    int i = int(k.x);
    int j = min(i + 1, clamp(count, 1, 8) - 1);
    return mix(values[i], values[j], kit_ease_smooth(k.y));
}

// --- Timing ------------------------------------------------------------------

// kit_on_twos(t, fps): hold time still between drawings, so motion steps like hand
// drawn animation while the film renders at its own frame rate. Animate with the
// returned time instead of t.
//   t    time in seconds (iShotTime, iTime), >= 0; the rounding guard below holds
//        for the first ten minutes or so, past that float steps outgrow it
//   fps  drawings per second: 12 is "on twos" in a 24 fps film, 8 "on threes", 6 on
//        fours; <= 0 returns t unchanged
//   ->   the time of the drawing on screen at t: a whole number of drawings, in
//        seconds. A t within a thousandth of a drawing before the next one counts as
//        the next, so frame times that should land exactly on a drawing don't lose
//        it to rounding
//   e.g. float ta = kit_on_twos(iShotTime, 12.0);   // then use ta wherever you'd use iShotTime
float kit_on_twos(float t, float fps) {
    if (fps <= 0.0) return t;
    return floor(t * fps + 1e-3) / fps;
}
