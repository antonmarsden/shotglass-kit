// Two balls do the same cartoon jump: the top one on ones (a new drawing every film
// frame), the bottom one on twos (kit_on_twos: 12 drawings a second, each held for
// two frames). A crouch before the leap (kit_anticipate, squashing instead of sinking
// into the floor), a leap that stretches with speed, three bounces (kit_ease_bounce_out)
// that squash on impact, then a wobble as it settles (kit_settle). Keyed poses move it
// across (kit_keys), point its eyes (kit_pose, vec2) and blush it (kit_pose, vec3).
// The ball is a 3D ball seen side on, so it keeps its volume (kit_squash, vec3); its
// shadow is flat and keeps its area (kit_squash, vec2).
// On the right, every ease and helper in core/animate.glsl, plotted 0..1 across, with
// the default in ink and a variant (other overshoot, cycles, on twos) in grey.
#include <kit/ease.glsl>
#include <kit/animate.glsl>
#include <kit/sdf.glsl>
#include <kit/color.glsl>

const vec3 INK = vec3(0.13, 0.10, 0.13);
const float R = 0.06;       // ball radius
const float H = 0.30;       // leap height
const float WIND = 0.25;    // wind-up depth, as a fraction of the leap

// The ball's height above the floor at time t: crouch 0.3..0.8, leap to 1.3, then
// fall and bounce until 2.6. Negative while crouching (turned into a squash below).
float height(float t) {
    if (t < 1.3) return H * kit_anticipate(kit_tween(0.3, 1.3, t), WIND, 0.5);
    return H * (1.0 - kit_ease_bounce_out(kit_tween(1.3, 2.6, t)));
}

float fill(float d, float px) { return 1.0 - smoothstep(-px, px, d); }

// One lane: the ball's floor at y = floorY, animated with time ta.
vec3 lane(vec3 col, vec2 p, float px, float floorY, float ta, vec3 body) {
    // Keys: rest, crouch, take off, land, rest. Across: hold until take-off (0.8),
    // ease over to the right by the last landing (2.45).
    float times[8] = float[8](0.0, 0.8, 2.45, 4.0, 0.0, 0.0, 0.0, 0.0);
    vec2 k = kit_keys(ta, times, 4, 0.0);
    float xs[4] = float[4](-0.72, -0.72, 0.02, 0.02);
    int i = int(k.x);
    float x = mix(xs[i], xs[i + 1], kit_ease_inout(k.y));

    // Squash and stretch: stretched by vertical speed in the air, squashed by the
    // crouch, by each impact (the faster the landing, the flatter), then the settle.
    float h = height(ta);
    float v = (height(ta + 0.01) - height(ta - 0.01)) / 0.02;
    float air = smoothstep(0.0, 0.04, h);          // 0 touching the floor
    float s = mix(1.0, kit_stretch_speed(v, 0.25), air);
    float crouch = max(-h, 0.0) / (WIND * H);
    // At a landing the curve has a corner, so take the faster of the two sides.
    float hit = max(abs(height(ta + 0.01) - h), abs(h - height(ta - 0.01))) / 0.01;
    float impact = hit * 0.6 * (1.0 - air) * step(1.3, ta);
    s *= kit_squash_impact(max(crouch * 0.7, impact));
    s += kit_settle(kit_tween(2.6, 3.5, ta), -0.25, 2.0);
    h = max(h, 0.0);

    // Shadow on the floor: wider and fainter as the ball rises.
    vec2 c0 = vec2(x, floorY);
    float lift = h / H;
    vec2 sq = kit_squash(p - c0, vec2(1.0, 0.0), 1.0 + 0.6 * (1.0 - lift));
    float shadow = kit_sd_circle(sq * vec2(1.0, 4.0), R * 0.9) / 4.0;
    col = mix(col, col * 0.6, fill(shadow, px) * (1.0 - 0.6 * lift));

    // The ball: squashed about its contact point, so it stays on the floor.
    vec3 q = kit_squash(vec3(p - c0 - vec2(0.0, h), 0.0), vec3(0.0, 1.0, 0.0), s) - vec3(0.0, R, 0.0);
    float d = (length(q.xy) - R) * min(s, inversesqrt(s));
    float times5[8] = float[8](0.0, 0.5, 0.8, 1.2, 1.7, 2.6, 0.0, 0.0);
    vec3 tint = kit_pose(ta, times5, vec3[8](body, body, body * vec3(1.15, 0.85, 0.85),
                         body, body, body, body, body), 6, 0.1);
    vec3 n = vec3(q.xy, sqrt(max(R * R - dot(q.xy, q.xy), 0.0))) / R;
    float lit = 0.35 + 0.65 * max(dot(n, normalize(vec3(-0.5, 0.7, 0.6))), 0.0);
    vec3 ball = tint * lit + 0.25 * pow(max(dot(n, normalize(vec3(-0.4, 0.6, 1.0))), 0.0), 24.0);
    col = mix(col, ball, fill(d, px));
    col = mix(col, INK, fill(abs(d) - 0.003, px));

    // Eyes: look down at the floor in the crouch, up while leaping, ahead when landing.
    vec2 look = kit_pose(ta, times5, vec2[8](vec2(0.4, 0.0), vec2(0.3, -0.6), vec2(0.3, -0.6),
                         vec2(0.2, 0.8), vec2(0.6, -0.3), vec2(0.0, 0.0), vec2(0.0), vec2(0.0)), 6, 0.08);
    for (int e = 0; e < 2; e++) {
        vec2 eye = vec2(0.012 + 0.025 * float(e), 0.012);
        float de = (length(q.xy - eye) - 0.011) * min(s, inversesqrt(s));
        col = mix(col, vec3(1.0), fill(de, px));
        float dp = (length(q.xy - eye - 0.005 * look) - 0.005) * min(s, inversesqrt(s));
        col = mix(col, INK, fill(dp, px));
    }

    // Floor line, and one or two dots at its left end: on ones, on twos.
    col = mix(col, INK, fill(abs(p.y - floorY) - 0.002, px) * step(p.x, 0.2));
    return col;
}

// Draws y = f over a plot cell: u is 0..1 across, vy the pixel's height in curve units,
// slope df/du; sx, sy turn curve units across and up into frame heights.
vec3 curve(vec3 col, float u, float vy, float f, float slope, vec3 ink, float px, float sx, float sy) {
    float m = slope * sy / sx;
    float d = abs(vy - f) * sy / sqrt(1.0 + m * m);
    return mix(col, ink, fill(d - 0.0015, px) * step(0.0, u) * step(u, 1.0));
}

// Plot n (0..11) at x.
float plot(int n, float x, bool alt) {
    float t4[8] = float[8](0.0, 0.3, 0.6, 1.0, 0.0, 0.0, 0.0, 0.0);
    float v4[8] = float[8](0.0, 0.8, 0.3, 1.0, 0.0, 0.0, 0.0, 0.0);
    if (n == 0) return alt ? kit_ease_back_in(x, 2.59) : kit_ease_back_in(x);
    if (n == 1) return alt ? kit_ease_back_out(x, 2.59) : kit_ease_back_out(x);
    if (n == 2) return alt ? kit_ease_back_inout(x, 2.59) : kit_ease_back_inout(x);
    if (n == 3) return alt ? kit_ease_elastic_in(x, 2.0) : kit_ease_elastic_in(x);
    if (n == 4) return alt ? kit_ease_elastic_out(x, 5.0) : kit_ease_elastic_out(x);
    if (n == 5) return alt ? kit_ease_elastic_inout(x, 1.5) : kit_ease_elastic_inout(x);
    if (n == 6) return alt ? kit_ease_bounce_in(kit_on_twos(x, 12.0)) : kit_ease_bounce_in(x);
    if (n == 7) return alt ? kit_ease_bounce_out(kit_on_twos(x, 12.0)) : kit_ease_bounce_out(x);
    if (n == 8) return alt ? kit_ease_bounce_inout(kit_on_twos(x, 12.0)) : kit_ease_bounce_inout(x);
    if (n == 9) return kit_anticipate(x, alt ? 0.35 : 0.2, alt ? 0.2 : 0.35);
    if (n == 10) return 0.5 + kit_settle(x, alt ? -0.2 : 0.3, alt ? 3.0 : 2.0);
    return kit_pose(alt ? kit_on_twos(x, 8.0) : x, t4, v4, 4, 0.1);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;   // y up, frame height 1
    float px = 1.0 / iResolution.y;
    float t = iShotTime;

    vec3 col = mix(vec3(0.99, 0.94, 0.84), vec3(0.86, 0.90, 0.97), uv.y);

    // Two lanes: on ones above, on twos below. The dots at the left say which.
    col = lane(col, p, px, 0.03, t, vec3(0.90, 0.32, 0.25));
    col = lane(col, p, px, -0.44, kit_on_twos(t, 12.0), vec3(0.25, 0.45, 0.85));
    col = mix(col, INK, fill(kit_sd_circle(p - vec2(-0.84, 0.05), 0.01), px));
    col = mix(col, INK, fill(min(kit_sd_circle(p - vec2(-0.85, -0.42), 0.01),
                                 kit_sd_circle(p - vec2(-0.82, -0.42), 0.01)), px));

    // The plots: 3 across, 4 down, each cell 0.2 x 0.24.
    vec2 g = (p - vec2(0.26, -0.48)) / vec2(0.2, 0.24);
    if (g.x >= 0.0 && g.x < 3.0 && g.y >= 0.0 && g.y < 4.0) {
        vec2 cell = floor(g);
        vec2 f = fract(g);
        int n = int(cell.x) + 3 * (3 - int(cell.y));
        float u = (f.x - 0.1) / 0.8;                 // 0..1 across the middle 80%
        float vy = (f.y - 0.1) / 0.8 * 1.8 - 0.4;    // -0.4..1.4 up the cell
        float sx = 0.2 * 0.8;                        // curve units -> frame heights
        float scale = 0.24 * 0.8 / 1.8;
        col = mix(col, vec3(1.0), 0.5);
        // axes: 0 and 1
        col = mix(col, vec3(0.75), fill(min(abs(vy), abs(vy - 1.0)) * scale - 0.0008, px));
        float e = 0.002;
        for (int a = 1; a >= 0; a--) {
            bool alt = a == 1;
            float y0 = plot(n, u, alt);
            float slope = (plot(n, u + e, alt) - plot(n, u - e, alt)) / (2.0 * e);
            if (alt && abs(slope) > 20.0) slope = 0.0;   // a jump between drawings: draw the holds only
            col = curve(col, u, vy, y0, slope, alt ? vec3(0.62) : INK, px, sx, scale);
        }
        // a dot riding the default curve
        float xd = kit_tween(0.2, 3.8, t);
        vec2 dot2 = vec2((0.1 + 0.8 * xd) * 0.2, (0.1 + 0.8 * (plot(n, xd, false) + 0.4) / 1.8) * 0.24);
        col = mix(col, vec3(0.90, 0.32, 0.25), fill(length(f * vec2(0.2, 0.24) - dot2) - 0.007, px));
        // cell border
        vec2 b = min(f, 1.0 - f) * vec2(0.2, 0.24);
        col = mix(col, vec3(0.6), fill(min(b.x, b.y) - 0.001, px));
    }

    col *= kit_vignette(uv, 0.25, 0.6);
    fragColor = vec4(col, 1.0);
}
