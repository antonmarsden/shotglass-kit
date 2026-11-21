// A sculpture garden, raymarched with core/raymarch.glsl: a ring of columns, a field
// of posts of random heights, a carved cube and two shapes melting into each other,
// with soft shadows and ambient occlusion. Uses every function in raymarch.glsl and
// sdf_ops.glsl.
#include <kit/ease.glsl>
#include <kit/noise.glsl>
#include <kit/color.glsl>
#include <kit/sdf.glsl>
#include <kit/sdf_ops.glsl>
#include <kit/raymarch.glsl>

const float FLOOR = 0.0, COLUMN = 1.0, POST = 2.0, CUBE = 3.0, BLOB = 4.0;

// The melting pair: a sphere and a box, sliding together and apart.
vec2 blob(vec3 p) {
    float slide = 0.15 * sin(iTime * 1.3);
    return kit_op_smin_blend(kit_sd_sphere(p - vec3(-0.35 - slide, 0.45, 0.0), 0.35),
                             kit_sd_box(p - vec3(0.15 + slide, 0.35, 0.0), vec3(0.25, 0.35, 0.25)),
                             0.35);
}

// The scene with materials: vec2(distance, material).
vec2 world(vec3 p) {
    vec2 d = vec2(kit_sd_plane(p, vec3(0.0, 1.0, 0.0), 0.0), FLOOR);

    // Eight columns in a ring of radius 2.6.
    vec3 q = p;
    q.xz = kit_op_repeat_polar(p.xz, 8.0);
    d = kit_op_union(d, vec2(kit_sd_cylinder(q - vec3(2.6, 0.7, 0.0), 0.12, 0.7), COLUMN));

    // A 5 x 3 field of posts behind the ring, each a random height.
    vec3 f = p - vec3(0.0, 0.0, -4.2);
    vec3 s = vec3(0.7, 1.0, 0.7);
    vec3 c = kit_op_repeat_limited(f, s, vec3(2.0, 0.0, 1.0));
    float h = 0.2 + 0.5 * kit_hash(kit_op_repeat_id(f, s));
    float post = kit_sd_box(c - vec3(0.0, h, 0.0), vec3(0.15, h, 0.15));
    // Posts differ, so a short post's distance can overshoot a taller neighbour. No
    // neighbour is nearer than this cell's wall plus the 0.2 gap beyond it: cap there.
    vec2 wall = max(0.5 * s.xz - abs(c.xz), 0.0);
    post = min(post, min(wall.x, wall.y) + 0.2);
    d = kit_op_union(d, vec2(post, POST));

    // A cube with a sphere scooped out of it, the cut's edge softened.
    float cube = kit_sd_box(p - vec3(1.1, 0.3, 0.9), vec3(0.3));
    cube = kit_op_ssubtract(cube, kit_sd_sphere(p - vec3(1.1, 0.62, 0.9), 0.3), 0.05);
    d = kit_op_union(d, vec2(cube, CUBE));

    d = kit_op_union(d, vec2(blob(p - vec3(-0.4, 0.0, 0.2)).x, BLOB));
    return d;
}

float kit_scene(vec3 p) { return world(p).x; }

vec3 baseColor(float m, vec3 p) {
    if (m == FLOOR) {
        vec2 g = kit_op_repeat(p.xz, vec2(0.5));   // paving stones with dark joints
        float joint = smoothstep(0.23, 0.25, max(abs(g.x), abs(g.y)));
        float tint = 0.9 + 0.2 * kit_hash(kit_op_repeat_id(p.xz, vec2(0.5)));   // per stone
        return mix(vec3(0.36, 0.34, 0.30) * tint, vec3(0.12, 0.11, 0.10), joint);
    }
    if (m == COLUMN) return vec3(0.55, 0.52, 0.46);
    if (m == POST) return vec3(0.12, 0.20, 0.35);
    if (m == CUBE) return vec3(0.60, 0.30, 0.10);
    // The melting pair: red sphere, blue box, purple where they meet.
    float w = blob(p - vec3(-0.4, 0.0, 0.2)).y;
    return mix(vec3(0.65, 0.08, 0.05), vec3(0.05, 0.12, 0.60), w);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 sp = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // The camera circles the ring, rising a little.
    float a = 0.3 + 0.9 * kit_ease_inout(iShotProgress);
    vec3 ro = vec3(5.0 * sin(a), 1.6 + 0.6 * iShotProgress, 5.0 * cos(a));
    vec3 ta = vec3(0.0, 0.4, -0.6);
    vec3 fw = normalize(ta - ro);
    vec3 rt = normalize(cross(fw, vec3(0.0, 1.0, 0.0)));
    vec3 up = cross(rt, fw);
    vec3 rd = normalize(sp.x * rt + sp.y * up + 1.7 * fw);

    vec3 sky = mix(vec3(0.60, 0.65, 0.75), vec3(0.15, 0.30, 0.65), clamp(rd.y * 2.0, 0.0, 1.0));
    vec3 col = sky;
    float t = kit_raymarch(ro, rd, 160, 0.001, 30.0);
    if (t >= 0.0) {
        vec3 p = ro + rd * t;
        vec3 n = kit_normal(p, 0.001);
        vec3 sun = normalize(vec3(0.6, 0.8, 0.35));
        float sh = kit_soft_shadow(p + n * 0.002, sun, 0.01, 12.0, 10.0);
        float ao = kit_ao(p, n, 0.35);
        float diff = max(dot(n, sun), 0.0) * sh;
        float spec = pow(max(dot(reflect(rd, n), sun), 0.0), 32.0) * sh * 0.3;
        vec3 base = baseColor(world(p).y, p);
        col = base * (vec3(1.0, 0.90, 0.75) * 1.3 * diff + vec3(0.25, 0.32, 0.48) * ao) + spec;
        col = mix(col, sky, 1.0 - exp(-0.001 * t * t));   // haze
    }

    col = kit_srgb_encode(kit_aces(col));
    col *= kit_vignette(uv, 0.3, 0.6);
    col = kit_grain(col, fragCoord, iFrame, 0.02);
    fragColor = vec4(col, 1.0);
}
