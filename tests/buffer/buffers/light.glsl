// Light painting: a long exposure of a sparkler waved in front of the camera. The
// state is the exposure so far (linear light x seconds, rgba16f): each frame adds the
// light that arrived during it (kit_buf_expose), as an open shutter does, so nothing
// fades; crossings and slow passages add up and burn out to white once tonemapped.
//
// - The head is a tiny white-hot point. Its light is spread along the stretch of path
//   it covered this frame, so the line is brighter where the hand slows down.
// - The hand wobbles (value noise) and its speed varies along the figure.
// - Sparks are ballistic: born from the head at hashed times, with hashed velocities,
//   falling under gravity, cooling from white through yellow and orange to red, and
//   forking into two smaller sparks part way through their life. Each is a closed form
//   of its birth time and hash, so there is no particle state: every frame draws the
//   stretch of each spark's path it covered during the frame. Over the exposure these
//   become the fine curved streaks round the stroke.
// - From 2.6 s the sparkler burns out: the head dims and stops shedding sparks, the
//   last sparks finish their flight, and the picture holds the finished photograph.
#include <kit/noise.glsl>
#include <buffer/math.glsl>

const float LOOKBACK = 12.0;             // frames of spark births drawn (longest life 0.4 s)
const int PER_FRAME = 2;                 // sparks born per frame at full burn
const vec2 GRAVITY = vec2(0.0, -1.4);    // frame heights / s²

float burn(float t) { return 1.0 - smoothstep(2.6, 3.2, t); }

vec2 head(float t, float aspect) {
    // A rose figure drawn by hand: uneven speed along it, a small wobble on top.
    float s = t + 0.22 * sin(1.9 * t);
    float a = 2.6 * s;
    float r = 0.28 * cos(1.5 * a) + 0.06;
    vec2 wob = vec2(kit_value_noise(vec2(2.3 * t, 3.0)), kit_value_noise(vec2(2.3 * t, 9.0))) - 0.5;
    return vec2(0.5 * aspect + 0.4 * sin(0.37 * t), 0.53) + r * vec2(cos(a), sin(a)) + 0.03 * wob;
}

// Light spread along a segment: a thin line whose energy per second is shared over
// the segment's length, so a short (slow) segment is brighter. Its ends ramp linearly
// over one line width either side of each endpoint instead of having round caps, so
// where one piece ends and the next begins (this frame's and the next frame's, or two
// pieces of one frame) the two ramps sum to one: no bright bead at the joint.
float line(vec2 p, vec2 a, vec2 b, float width, float px) {
    vec2 ab = b - a;
    float len = length(ab);
    float spread = px / max(len, px);
    if (len < 1e-6) return exp2(-dot(p - a, p - a) / (width * width)) * spread;
    vec2 dir = ab / len;
    float s = dot(p - a, dir);                       // along the segment
    float d = abs(dot(p - a, vec2(-dir.y, dir.x)));  // across it
    float h = width;
    float ends = clamp((s + h) / (2.0 * h), 0.0, 1.0) * clamp((len + h - s) / (2.0 * h), 0.0, 1.0);
    return exp2(-d * d / (width * width)) * ends * spread;
}

// Colour of a cooling spark, u = age / life: white, yellow, orange, deep red.
vec3 ember(float u) {
    vec3 c = mix(vec3(1.0, 0.95, 0.85), vec3(1.0, 0.75, 0.3), smoothstep(0.0, 0.3, u));
    c = mix(c, vec3(1.0, 0.4, 0.1), smoothstep(0.3, 0.7, u));
    return mix(c, vec3(0.6, 0.1, 0.02), smoothstep(0.7, 1.0, u));
}

// One ballistic path from p0 with velocity v, over ages a0..a1 (seconds since it
// started) clipped to its life, drawn as two straight pieces.
vec3 flight(vec2 p, vec2 p0, vec2 v, float a0, float a1, float life, float power, float px) {
    a0 = max(a0, 0.0);
    a1 = min(a1, life);
    if (a1 <= a0) return vec3(0.0);
    float am = 0.5 * (a0 + a1);
    vec2 q0 = p0 + v * a0 + 0.5 * GRAVITY * a0 * a0;
    vec2 qm = p0 + v * am + 0.5 * GRAVITY * am * am;
    vec2 q1 = p0 + v * a1 + 0.5 * GRAVITY * a1 * a1;
    float u = am / life;
    float l = line(p, q0, qm, 0.6 * px, px) + line(p, qm, q1, 0.6 * px, px);
    return ember(u) * power * pow(1.0 - u, 1.5) * l;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float aspect = iResolution.x / iResolution.y;
    vec2 p = fragCoord / iResolution.y;
    float px = 1.0 / iResolution.y;
    float dt = iTimeDelta;
    float t1 = iTime;
    float t0 = iTime - dt;

    // The head: this frame's stretch of path in 6 pieces, white-hot.
    vec3 light = vec3(0.0);
    float b = burn(t1);
    vec2 a = head(t0, aspect);
    for (int i = 1; i <= 6; i++) {
        vec2 c = head(mix(t0, t1, float(i) / 6.0), aspect);
        light += vec3(1.0, 0.8, 0.55) * 160.0 * b * line(p, a, c, 0.8 * px, px) / 6.0;
        a = c;
    }

    // Sparks born in the last LOOKBACK frames (frames since the reset, so the same
    // sparks whichever way the fold is reached).
    for (float k = 0.0; k <= LOOKBACK; k += 1.0) {
        int f = iFrame - int(k);
        if (f < 0) break;
        for (int j = 0; j < PER_FRAME; j++) {
            ivec3 id = ivec3(f, j, 0);
            float tb = (float(f) + kit_hash(id)) * dt;
            if (kit_hash(id + ivec3(0, 0, 1)) > burn(tb)) continue;   // fewer as it dies
            vec2 o = head(tb, aspect);
            if (length(p - o) > 0.7) continue;
            float ang = 6.28318531 * kit_hash(id + ivec3(0, 0, 2));
            float speed = 0.5 + 0.9 * kit_hash(id + ivec3(0, 0, 3));
            vec2 v = speed * vec2(cos(ang), sin(ang));
            float life = 0.12 + 0.28 * kit_hash(id + ivec3(0, 0, 4));
            float split = life * (0.35 + 0.25 * kit_hash(id + ivec3(0, 0, 5)));
            float a0 = t0 - tb;
            float a1 = t1 - tb;
            // The parent, up to where it forks.
            light += flight(p, o, v, a0, a1, split, 32.0, px);
            // Two children from the fork, each with a kick and a short life of its own.
            vec2 fork = o + v * split + 0.5 * GRAVITY * split * split;
            vec2 vf = v + GRAVITY * split;
            for (int c = 0; c < 2; c++) {
                float ca = 6.28318531 * kit_hash(id + ivec3(0, 0, 6 + c));
                vec2 vc = 0.8 * vf + 0.45 * vec2(cos(ca), sin(ca));
                float cl = 0.08 + 0.14 * kit_hash(id + ivec3(0, 0, 8 + c));
                light += flight(p, fork, vc, a0 - split, a1 - split, cl, 18.0, px);
            }
        }
    }
    fragColor = kit_buf_expose(texelFetch(iChannel0, ivec2(fragCoord), 0), vec4(light, 0.0), dt);
}
