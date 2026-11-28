// Light painting: a sparkler traces a looping figure in front of the camera and the
// exposure keeps it, fading with a half-life (kit_buf_trail). The stroke is drawn as
// the segments the sparkler crossed during this frame, so it stays continuous at any
// frame rate; sparks fly off the head. State: linear HDR light, alpha unused.
#include <kit/noise.glsl>
#include <kit/sdf.glsl>
#include <buffer/math.glsl>

#ifndef SG_HAS_uHalfLife
const float uHalfLife = 2.0;
#endif

vec2 head(float t, float aspect) {
    // A rose curve drifting across: the kind of loop drawn with a sparkler.
    float a = 2.6 * t;
    float r = 0.28 * cos(1.5 * a) + 0.06;
    return vec2(0.5 * aspect + 0.45 * sin(0.37 * t), 0.52) + r * vec2(cos(a), sin(a));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float aspect = iResolution.x / iResolution.y;
    vec2 p = fragCoord / iResolution.y;
    float px = 1.0 / iResolution.y;
    float t1 = iTime;
    float t0 = iTime - iTimeDelta;
    // The stroke: 6 sub-segments of this frame's motion.
    float d = 1e9;
    vec2 a = head(t0, aspect);
    for (int i = 1; i <= 6; i++) {
        vec2 b = head(mix(t0, t1, float(i) / 6.0), aspect);
        d = min(d, kit_sd_segment(p, a, b));
        a = b;
    }
    float core = exp2(-d * d / (px * px * 0.8));
    float halo = exp2(-d / (2.5 * px));
    vec3 hot = vec3(1.0, 0.55, 0.18);
    vec3 elem = hot * (1.2 * core + 0.10 * halo) + vec3(1.0) * 0.6 * core;
    // Sparks: short streaks thrown from the head at random this frame.
    vec2 h = head(t1, aspect);
    for (int i = 0; i < 3; i++) {
        float r1 = kit_hash(ivec2(iFrame, i));
        float r2 = kit_hash(ivec2(iFrame, i + 64));
        vec2 dir = vec2(cos(6.28318531 * r1), sin(6.28318531 * r1));
        vec2 s0 = h + dir * (0.01 + 0.06 * r2);
        float sd = kit_sd_segment(p, s0, s0 + dir * 0.01);
        elem += vec3(1.0, 0.75, 0.35) * 0.5 * exp2(-sd * sd / (px * px * 0.6));
    }
    fragColor = kit_buf_trail(texelFetch(iChannel0, ivec2(fragCoord), 0), vec4(elem, 1.0), uHalfLife, iTimeDelta);
}
