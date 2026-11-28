// shotglass-kit/buffer: math.glsl
//
// The maths of feedback buffers ([[buffer]], shotglass 0.1.9+) on plain values, so it
// can be unit-tested: decay from a half-life, trails, discrete Laplacians, the wave
// equation, Gray-Scott reaction-diffusion with named presets, Conway's rule,
// feedback transforms, seeds for the first frame after a reset, and packing state
// into 8-bit channels. buffer/sample.glsl reads the samplers and calls these.
//
// Determinism: a buffer's state is the fold of one step per film frame from its last
// reset, so every helper here is a function of its arguments only. Time enters as
// `dt`, the step's length in seconds: pass iTimeDelta, which shotglass makes exactly
// 1/fps in a buffer, never anything measured. Nothing depends on render scale.
// Feedback magnifies rounding: keep angles and rates constant over a fold where you
// can, so GPUs that differ by an ULP per step don't drift apart faster than needed.
// sound: picture only
#include <shotglass-kit/core/noise.glsl>

// kit_buf_decay(halfLife, dt): the factor that halves a value every halfLife seconds,
// for one step of dt seconds. Frame-rate independent: n steps of 1/n s multiply to
// the same as one step of 1 s.
//   halfLife  seconds; <= 0 gives 0 (forget at once)
//   dt        step length in seconds (iTimeDelta), >= 0
//   ->        0..1; 1 when dt = 0
//   e.g. float f = kit_buf_decay(0.5, iTimeDelta);
float kit_buf_decay(float halfLife, float dt) {
    if (halfLife <= 0.0) return 0.0;
    return exp2(-max(dt, 0.0) / halfLife);
}

// kit_buf_trail(prev, elem, halfLife, dt): the brighter of a new element and the
// decayed previous state, per channel: light painting, long exposures, comet tails.
// Premultiplied-alpha safe (decay scales colour and alpha together; max keeps
// rgb <= a when both inputs do).
//   prev, elem  states (any units, typically premultiplied colour)
//   ->          max(elem, prev * kit_buf_decay(halfLife, dt))
//   e.g. vec4 s = kit_buf_trail(vec4(0.5), vec4(0.0), 0.25, iTimeDelta);
vec4 kit_buf_trail(vec4 prev, vec4 elem, float halfLife, float dt) {
    return max(elem, prev * kit_buf_decay(halfLife, dt));
}

// kit_buf_trail_over(prev, elem, halfLife, dt): a premultiplied element composited
// over its decayed previous state ("over" instead of "max"): dark or translucent
// elements leave trails too, and the result stays premultiplied.
//   prev, elem  premultiplied colours, alpha 0..1
//   ->          elem + decayed prev * (1 - elem.a)
//   e.g. vec4 s = kit_buf_trail_over(vec4(0.2), vec4(0.0), 1.0, iTimeDelta);
vec4 kit_buf_trail_over(vec4 prev, vec4 elem, float halfLife, float dt) {
    return elem + prev * kit_buf_decay(halfLife, dt) * (1.0 - clamp(elem.a, 0.0, 1.0));
}

// kit_buf_laplacian(c, e, w, n, s): 5-point discrete Laplacian, per texel squared.
//   c        the centre value; e, w, n, s its four neighbours one texel away
//   ->       e + w + n + s - 4c (0 for any linear ramp)
vec4 kit_buf_laplacian(vec4 c, vec4 e, vec4 w, vec4 n, vec4 s) {
    return e + w + n + s - 4.0 * c;
}

// kit_buf_laplacian(c, edges, corners): 9-point isotropic Laplacian,
// (4 edges + corners - 20 c) / 6: exact on quadratics like the 5-point one, and
// less grid-shaped for diffusion and reaction-diffusion.
//   c        centre value
//   edges    sum of the four edge neighbours; corners  sum of the four corners
//   ->       per texel squared, 0 for any linear ramp
vec4 kit_buf_laplacian(vec4 c, vec4 edges, vec4 corners) {
    return (4.0 * edges + corners - 20.0 * c) / 6.0;
}

// kit_buf_wave(cur, prev, lap, speed, halfLife, dt): one step of the damped wave
// equation from two frames of history (the state now and one step before): ripples.
// The step is one film frame; halfLife damps it in seconds.
//   cur, prev  height now and one step before (@prev and frame = -2 of the state)
//   lap        kit_buf_laplacian of cur
//   speed      texels per step, clamped to 0..0.7 (above 1/sqrt(2) it's unstable)
//   halfLife   seconds for the ripples to halve; <= 0 stops them at once
//   dt         step length in seconds (iTimeDelta)
//   ->         height for the next step
//   e.g. float h = kit_buf_wave(0.1, 0.0, -0.4, 0.5, 1.0, iTimeDelta);
float kit_buf_wave(float cur, float prev, float lap, float speed, float halfLife, float dt) {
    float c = clamp(speed, 0.0, 0.7);
    return (2.0 * cur - prev + c * c * lap) * kit_buf_decay(halfLife, dt);
}

// Gray-Scott presets: vec2(feed, kill) for kit_buf_gray_scott, named after the
// patterns they grow from a few seeds.
//   e.g. vec2 fk = kit_buf_gs_coral();
vec2 kit_buf_gs_coral() { return vec2(0.0545, 0.062); }       // branching coral
vec2 kit_buf_gs_mitosis() { return vec2(0.0367, 0.0649); }    // dividing spots
vec2 kit_buf_gs_maze() { return vec2(0.029, 0.057); }         // labyrinth stripes
vec2 kit_buf_gs_spots() { return vec2(0.03, 0.062); }         // stable spots
vec2 kit_buf_gs_waves() { return vec2(0.014, 0.045); }        // pulsing waves

// kit_buf_gray_scott(ab, lap, fk): one Gray-Scott reaction-diffusion step (one per
// film frame; chain buffers for several per frame). Diffusion 0.25 texel² per step
// for A and 0.125 for B (Karl Sims' 1.0 and 0.5 with a Laplacian normalised to sum
// to 1): stable with either Laplacian above.
//   ab   vec2(A, B) concentrations, 0..1 (A = 1, B = 0 is the empty state)
//   lap  the Laplacian of ab
//   fk   vec2(feed, kill), from a preset above or your own (0..0.1 each)
//   ->   the next vec2(A, B), clamped to 0..1
//   e.g. vec2 ab = kit_buf_gray_scott(vec2(1.0, 0.0), vec2(0.0), kit_buf_gs_coral());
vec2 kit_buf_gray_scott(vec2 ab, vec2 lap, vec2 fk) {
    float abb = ab.x * ab.y * ab.y;
    vec2 d = vec2(0.25 * lap.x - abb + fk.x * (1.0 - ab.x),
                  0.125 * lap.y + abb - (fk.x + fk.y) * ab.y);
    return clamp(ab + d, 0.0, 1.0);
}

// kit_buf_life(alive, neighbours): Conway's Game of Life rule.
//   alive       the cell now, > 0.5 means alive
//   neighbours  live cells among the 8 around it (their states summed; rounded)
//   ->          1.0 or 0.0, the cell next step
float kit_buf_life(float alive, float neighbours) {
    int n = int(floor(clamp(neighbours, 0.0, 8.0) + 0.5));
    return (n == 3 || (alive > 0.5 && n == 2)) ? 1.0 : 0.0;
}

// kit_buf_zoom_uv(uv, center, zoom, angle, aspect): where to read the previous state
// so the picture grows by `zoom` and turns by `angle` about `center` each step: video
// feedback, infinite zoom. Turns are done in frame heights, so they stay round.
//   uv      frame position, 0..1
//   center  the fixed point, uv
//   zoom    growth per step (1.05 = 5% bigger each step; < 1 shrinks), > 0
//   angle   radians per step, anticlockwise
//   aspect  width / height of the buffer
//   ->      uv to read (may fall outside 0..1: weigh it with kit_buf_edge_fade)
//   e.g. vec2 q = kit_buf_zoom_uv(vec2(0.25), vec2(0.5), 1.02, 0.01, 16.0 / 9.0);
vec2 kit_buf_zoom_uv(vec2 uv, vec2 center, float zoom, float angle, float aspect) {
    vec2 a = vec2(aspect, 1.0);
    vec2 p = (uv - center) * a / max(zoom, 1e-6);
    float c = cos(angle);
    float s = sin(angle);
    p = mat2(c, -s, s, c) * p;        // the inverse turn: where the texel came from
    return center + p / a;
}

// kit_buf_advect_uv(uv, vel, dt): semi-Lagrangian back-trace: where the stuff now at
// uv was one step before, for a velocity in uv per second. Read the previous state
// there to move it along the field.
//   uv   frame position, 0..1
//   vel  velocity, uv per second
//   dt   step length in seconds (iTimeDelta)
//   ->   uv - vel * dt
vec2 kit_buf_advect_uv(vec2 uv, vec2 vel, float dt) { return uv - vel * dt; }

// kit_buf_edge_fade(uv, width): 1 well inside the frame, falling to 0 at its edges
// over `width` (uv); 0 outside. Weighs feedback reads so edges don't smear inwards.
//   uv     position, any range
//   width  0..0.5; 0 gives a hard edge (1 on 0..1 inclusive, else 0)
//   ->     0..1
float kit_buf_edge_fade(vec2 uv, float width) {
    vec2 d = min(uv, 1.0 - uv);
    float m = min(d.x, d.y);
    if (width <= 0.0) return m >= 0.0 ? 1.0 : 0.0;
    return clamp(m / width, 0.0, 1.0);
}

// kit_buf_seed_disc(p, c, r, softness): a soft disc, for an init pass or a splat.
//   p, c      position and centre, frame heights
//   r         radius, frame heights
//   softness  edge width, frame heights, >= 0
//   ->        1 inside, 0 outside, 0.5 on the circle
float kit_buf_seed_disc(vec2 p, vec2 c, float r, float softness) {
    float d = length(p - c) - r;
    float h = 0.5 * max(softness, 1e-6);
    return 1.0 - smoothstep(-h, h, d);
}

// kit_buf_seed_noise(cell, seed, density): sparse random seeds, one per texel: 1 for
// about `density` of the cells, else 0. The same bits on every GPU (kit_hash).
//   cell     integer texel, ivec2(fragCoord)
//   seed     any integer, e.g. which reset this is
//   density  0..1
//   ->       0.0 or 1.0
//   cost: 1 hash
float kit_buf_seed_noise(ivec2 cell, int seed, float density) {
    return kit_hash(ivec3(cell, seed)) < density ? 1.0 : 0.0;
}

// kit_buf_drop(p, c, r): a smooth bump to splash into a wave state: 1 at c, a
// Gaussian that is 0.1 at distance r.
//   p, c  position and centre, frame heights
//   r     radius, frame heights, > 0
//   ->    0..1
float kit_buf_drop(vec2 p, vec2 c, float r) {
    vec2 d = (p - c) / max(r, 1e-6);
    return exp2(-3.32192809 * dot(d, d));
}

// kit_buf_pack_signed(v, range): signed values in -range..range as 0..1 for an rgba8
// buffer (0.5 is zero). Precision in rgba8: range / 127.5 per step. Float formats
// (rgba16f, rgba32f) store signed values as they are and don't need it.
//   range  > 0
//   ->     0..1 (clamped)
vec4 kit_buf_pack_signed(vec4 v, float range) {
    return clamp(v / (2.0 * max(range, 1e-12)) + 0.5, 0.0, 1.0);
}

// kit_buf_unpack_signed(c, range): the inverse of kit_buf_pack_signed.
//   ->  -range..range
vec4 kit_buf_unpack_signed(vec4 c, float range) { return (c - 0.5) * (2.0 * range); }

// kit_buf_pack16(x): a 0..1 value split over two 8-bit channels (high, low): 16 bits
// of precision in an rgba8 buffer (exact to 1/65535 through an 8-bit round trip).
//   x   0..1 (clamped)
//   ->  vec2(high, low), each a multiple of 1/255
vec2 kit_buf_pack16(float x) {
    float v = floor(clamp(x, 0.0, 1.0) * 65535.0 + 0.5);
    float hi = floor(v / 256.0);
    return vec2(hi, v - hi * 256.0) / 255.0;
}

// kit_buf_unpack16(c): the inverse of kit_buf_pack16, from two 8-bit channels.
//   ->  0..1
float kit_buf_unpack16(vec2 c) {
    vec2 b = floor(c * 255.0 + 0.5);
    return (b.x * 256.0 + b.y) / 65535.0;
}
