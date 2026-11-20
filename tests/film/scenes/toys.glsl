// Toys on a table, raymarched: a bouncing ball, a block, a crayon, a cup, an egg and a
// string of beads. Uses every 3D shape in core/sdf.glsl and the operators on them.
#include <kit/ease.glsl>
#include <kit/color.glsl>
#include <kit/sdf.glsl>

vec2 nearest(vec2 a, vec2 b) { return a.x < b.x ? a : b; }   // (distance, material)

// Ball height: rises slowing down, falls speeding up. sfx/ball.glsl thuds on every landing
// (fract(...) wrapping to 0), so keep the 0.8 bounces per second in step with it.
float bounce() {
    float ph = fract(iTime * 0.8);
    return ph < 0.5 ? kit_ease_out(ph * 2.0) : 1.0 - kit_ease_in(ph * 2.0 - 1.0);
}

vec2 scene(vec3 p) {
    vec2 d = vec2(kit_sd_plane(p, vec3(0.0, 1.0, 0.0), 0.0), 0.0);

    d = nearest(d, vec2(kit_sd_sphere(p - vec3(-0.65, 0.22 + 0.45 * bounce(), 0.15), 0.22), 1.0));

    float block = kit_sd_round_box(p - vec3(0.45, 0.18, -0.15), vec3(0.18), 0.03);
    block = kit_op_subtract(block, kit_sd_sphere(p - vec3(0.45, 0.18, 0.06), 0.07));   // a dimple
    d = nearest(d, vec2(block, 2.0));

    d = nearest(d, vec2(kit_sd_capsule(p, vec3(-0.35, 0.05, 0.75), vec3(0.25, 0.05, 0.95), 0.05), 3.0));

    // A cup: a hollow cylinder with its top cut off, rim rounded.
    float cup = kit_op_onion(kit_sd_cylinder(p - vec3(1.0, 0.2, 0.45), 0.16, 0.2), 0.012);
    cup = kit_op_round(kit_op_intersect(cup, p.y - 0.37), 0.004);
    d = nearest(d, vec2(cup, 4.0));

    d = nearest(d, vec2(kit_sd_ellipsoid(p - vec3(-0.12, 0.16, -0.2), vec3(0.12, 0.16, 0.12)), 5.0));

    // Beads: one sphere repeated along x, kept to a short string, melted onto a thread.
    vec3 q = p - vec3(-0.2, 0.045, 0.35);
    float beads = kit_op_intersect(kit_sd_sphere(kit_op_repeat(q, vec3(0.11, 100.0, 100.0)), 0.045),
                                   kit_sd_box(q, vec3(0.3, 0.1, 0.1)));
    float thread = kit_sd_capsule(q, vec3(-0.36, 0.0, 0.0), vec3(0.36, 0.0, 0.0), 0.006);
    d = nearest(d, vec2(kit_op_smin(beads, thread, 0.015), 6.0));
    return d;
}

vec3 normalAt(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(scene(p + e.xyy).x - scene(p - e.xyy).x,
                          scene(p + e.yxy).x - scene(p - e.yxy).x,
                          scene(p + e.yyx).x - scene(p - e.yyx).x));
}

float softShadow(vec3 ro, vec3 rd) {
    float res = 1.0, t = 0.02;
    for (int i = 0; i < 40; i++) {
        float h = scene(ro + rd * t).x;
        res = min(res, 10.0 * h / t);
        t += clamp(h, 0.01, 0.2);
        if (res < 0.01 || t > 4.0) break;
    }
    return clamp(res, 0.0, 1.0);
}

vec3 materialColor(float m, vec3 p) {
    if (m < 0.5) {   // table: a soft checker
        vec2 c = floor(p.xz * 2.5);
        return mix(vec3(0.80, 0.70, 0.55), vec3(0.70, 0.58, 0.45), mod(c.x + c.y, 2.0));
    }
    return kit_srgb_decode(kit_palette(m * 0.14, vec3(0.6), vec3(0.4), vec3(1.0),
                                       vec3(0.0, 0.33, 0.67)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 sp = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // The camera swings slowly round the table.
    float a = 0.5 + 0.35 * kit_ease_inout(iShotProgress);
    vec3 ro = vec3(2.7 * sin(a), 1.35, 2.7 * cos(a));
    vec3 ta = vec3(0.15, 0.15, 0.15);
    vec3 fw = normalize(ta - ro);
    vec3 rt = normalize(cross(fw, vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(rt, fw);
    vec3 rd = normalize(sp.x * rt + sp.y * up + 1.6 * fw);

    vec3 bg = mix(vec3(0.95, 0.85, 0.75), vec3(0.55, 0.65, 0.85), uv.y);
    vec3 col = bg;
    float t = 0.0;
    vec2 hit = vec2(1e9, -1.0);
    for (int i = 0; i < 120; i++) {
        hit = scene(ro + rd * t);
        if (hit.x < 0.0005 * t || t > 12.0) break;
        t += hit.x;
    }
    if (t < 12.0) {
        vec3 p = ro + rd * t;
        vec3 n = normalAt(p);
        vec3 sun = normalize(vec3(-0.5, 0.9, 0.4));
        float diff = max(dot(n, sun), 0.0) * softShadow(p + n * 0.002, sun);
        float ao = clamp(scene(p + n * 0.08).x / 0.08, 0.0, 1.0);
        float spec = pow(max(dot(reflect(rd, n), sun), 0.0), 40.0) * (hit.y > 0.5 ? 0.6 : 0.1);
        vec3 base = materialColor(hit.y, p);
        col = base * (vec3(1.0, 0.92, 0.80) * 1.4 * diff + vec3(0.35, 0.42, 0.55) * (0.4 + 0.6 * ao))
            + spec;
        col = mix(col, bg, 1.0 - exp(-0.02 * t * t));   // a little haze
    }

    col = kit_srgb_encode(kit_aces(col));
    col *= kit_vignette(uv, 0.3, 0.6);
    col = kit_grain(col, fragCoord, iFrame, 0.02);
    fragColor = vec4(col, 1.0);
}
