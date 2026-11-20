// shotglass-kit/core: sdf.glsl
//
// Signed distance functions: the distance from p to a shape's surface, negative
// inside. Build a scene by combining them with the kit_op_ functions, then draw it
// in 2D (smoothstep on the distance) or raymarch it in 3D.
// Shapes are centred on the origin: move them by passing p - position.
// Lengths (radii, half-sizes, fillets) are in the units of p.
// sound: yes

// ---- 2D -------------------------------------------------------------------------

// kit_sd_circle(p, r): circle of radius r.
//   e.g. float d = kit_sd_circle(uv - vec2(0.5), 0.2);
//        col = mix(col, ink, 1.0 - smoothstep(0.0, 0.005, d));   // anti-aliased fill
float kit_sd_circle(vec2 p, float r) { return length(p) - r; }

// kit_sd_box(p, b): rectangle with half-size b (a 2 x 1 box has b = vec2(1, 0.5)).
float kit_sd_box(vec2 p, vec2 b) {
    vec2 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

// kit_sd_segment(p, a, b): distance to the line segment a-b (thicken with kit_op_round).
float kit_sd_segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-12), 0.0, 1.0);
    return length(pa - ba * h);
}

// ---- 3D -------------------------------------------------------------------------

// kit_sd_sphere(p, r): sphere of radius r.
float kit_sd_sphere(vec3 p, float r) { return length(p) - r; }

// kit_sd_box(p, b): box with half-size b.
float kit_sd_box(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// kit_sd_round_box(p, b, r): box with half-size b and edges rounded by r (r <= min(b)).
float kit_sd_round_box(vec3 p, vec3 b, float r) { return kit_sd_box(p, b - r) - r; }

// kit_sd_capsule(p, a, b, r): a sausage from a to b with radius r.
float kit_sd_capsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-12), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

// kit_sd_cylinder(p, r, h): upright (y axis) cylinder with radius r, height 2h.
float kit_sd_cylinder(vec3 p, float r, float h) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// kit_sd_plane(p, n, h): the plane dot(p, n) = -h; n must have length 1.
//   e.g. float ground = kit_sd_plane(p, vec3(0, 1, 0), 1.0);   // the plane y = -1
float kit_sd_plane(vec3 p, vec3 n, float h) { return dot(p, n) + h; }

// kit_sd_ellipsoid(p, r): ellipsoid with radii r. A bound, not exact: fine for
// raymarching and shading, but the distance is only exact on the surface.
float kit_sd_ellipsoid(vec3 p, vec3 r) {
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / max(k1, 1e-12);
}

// ---- combining (work in 2D and 3D) ------------------------------------------------

float kit_op_union(float a, float b) { return min(a, b); }
// a with b cut out of it
float kit_op_subtract(float a, float b) { return max(a, -b); }
float kit_op_intersect(float a, float b) { return max(a, b); }

// kit_op_smin(a, b, k): union with a smooth fillet of size k (k = 0: plain min).
//   e.g. float blob = kit_op_smin(kit_sd_sphere(p, 1.0), kit_sd_sphere(p - off, 0.7), 0.3);
float kit_op_smin(float a, float b, float k) {
    if (k <= 0.0) return min(a, b);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}
// kit_op_smax(a, b, k): intersection with a smooth edge of size k.
float kit_op_smax(float a, float b, float k) { return -kit_op_smin(-a, -b, k); }

// kit_op_round(d, r): grow a shape by r, rounding its corners.
float kit_op_round(float d, float r) { return d - r; }
// kit_op_onion(d, t): hollow a shape into a shell of thickness 2t.
float kit_op_onion(float d, float t) { return abs(d) - t; }

// kit_op_repeat(p, s): repeat space every s units (tile a shape forever). Use the
// returned position as the shape's p. s must be > 0 on every axis.
//   e.g. vec3 q = p;
//        q.xz = kit_op_repeat(p.xz, vec2(4.0));          // a pillar every 4 units
//        float pillars = kit_sd_cylinder(q, 0.3, 2.0);
// (floor(x + 0.5), not round(): round() may go either way at .5, depending on the driver.)
vec2 kit_op_repeat(vec2 p, vec2 s) { return p - s * floor(p / s + 0.5); }
vec3 kit_op_repeat(vec3 p, vec3 s) { return p - s * floor(p / s + 0.5); }
