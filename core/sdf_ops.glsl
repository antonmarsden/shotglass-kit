// shotglass-kit/core: sdf_ops.glsl
//
// More ways to combine and repeat signed distances, on top of the basic operators in
// sdf.glsl (kit_op_union, kit_op_smin, kit_op_subtract, kit_op_intersect, kit_op_smax,
// kit_op_repeat), which this file includes. Most are for 3D scenes you raymarch
// (raymarch.glsl), but every one works on 2D distances too.
// Distances, fillets and spacings are in the units of p.
// sound: yes
#include "sdf.glsl"

// ---- combining, with materials ----------------------------------------------------

// kit_op_union(a, b): the nearer of two (distance, material) pairs, so the material
// of whichever surface is closer comes along with the distance.
//   a, b  vec2(distance, material id); the id is yours to choose (0.0, 1.0, ...)
//   ->    a or b, whichever has the smaller distance (a on a tie)
//   e.g. vec2 d = kit_op_union(vec2(kit_sd_plane(p, vec3(0.0, 1.0, 0.0), 0.0), 0.0),
//                              vec2(kit_sd_sphere(p - vec3(0.0, 1.0, 0.0), 1.0), 1.0));
vec2 kit_op_union(vec2 a, vec2 b) { return a.x <= b.x ? a : b; }

// kit_op_smin_blend(a, b, k): smooth union (as kit_op_smin) that also says how much of
// each shape is at the surface, to blend their colours across the fillet.
//   a, b  distances
//   k     fillet size, >= 0 (0: plain min, a hard switch from a to b)
//   ->    vec2(distance, weight): weight 0 where a is the surface, 1 where b is, and
//         in between across the fillet
//   e.g. vec2 m = kit_op_smin_blend(kit_sd_sphere(p, 1.0), kit_sd_box(p - vec3(1.2, 0.0, 0.0), vec3(0.6)), 0.4);
//        vec3 base = mix(vec3(0.9, 0.2, 0.1), vec3(0.1, 0.3, 0.9), m.y);
vec2 kit_op_smin_blend(float a, float b, float k) {
    if (k <= 0.0) return a <= b ? vec2(a, 0.0) : vec2(b, 1.0);
    float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
    return vec2(kit_op_smin(a, b, k), h);
}

// kit_op_ssubtract(a, b, k): a with b cut out of it, the cut's edge rounded by k
// (k = 0: kit_op_subtract).
//   e.g. float d = kit_op_ssubtract(kit_sd_box(p, vec3(1.0)), kit_sd_sphere(p, 1.25), 0.1);
float kit_op_ssubtract(float a, float b, float k) { return kit_op_smax(a, -b, k); }

// ---- repeating --------------------------------------------------------------------

// kit_op_repeat_limited(p, s, n): repeat space every s units, but only n copies each
// side of the origin (2n + 1 in all, per axis), centred on the origin. Use the returned
// position as the shape's p. Beyond the last copy, space belongs to the last copy.
//   p   position
//   s   spacing, > 0 on every axis
//   n   copies each side of the origin, >= 0 per axis (0 on an axis: no repeat there)
//   ->  position within the copy
//   e.g. vec3 q = kit_op_repeat_limited(p, vec3(1.5, 1.0, 1.5), vec3(2.0, 0.0, 1.0));   // 5 x 1 x 3
//        float posts = kit_sd_box(q, vec3(0.2, 1.0, 0.2));
// The shape should fit inside one cell (half-size < s / 2); as with kit_op_repeat,
// a bigger one is cut off at the cell walls.
vec2 kit_op_repeat_limited(vec2 p, vec2 s, vec2 n) {
    return p - s * clamp(floor(p / s + 0.5), -n, n);
}
vec3 kit_op_repeat_limited(vec3 p, vec3 s, vec3 n) {
    return p - s * clamp(floor(p / s + 0.5), -n, n);
}

// kit_op_repeat_id(p, s): which copy of kit_op_repeat(p, s) p is in, as integers
// (0 at the origin, 1 the next copy along +x, ...). Feed it to kit_hash to vary
// each copy.
//   p   position, up to about +-10^6 copies from the origin
//   s   spacing, > 0 on every axis (the same s you gave kit_op_repeat)
//   ->  the copy's integer coordinates
//   e.g. float r = kit_hash(kit_op_repeat_id(p.xz, vec2(2.0)));   // one random number per copy
// Copies that differ (in size, height, position) break the distance: a copy only
// knows its own shape, so a small copy can report more distance than there is to a
// bigger neighbour, and rays step into it (speckles, streaks). Keep every copy well
// inside its cell and cap the distance at the cell wall plus the gap beyond it (see
// tests/film/scenes/garden.glsl), or step the raymarch by less than the distance.
ivec2 kit_op_repeat_id(vec2 p, vec2 s) { return ivec2(floor(p / s + 0.5)); }
ivec3 kit_op_repeat_id(vec3 p, vec3 s) { return ivec3(floor(p / s + 0.5)); }

// kit_op_repeat_polar(p, n): repeat space n times around the origin, like the spokes
// of a wheel. Use the returned position as the shape's p; place the shape along +x
// (angle 0). In 3D, repeat around the y axis by passing p.xz.
//   p   2D position (centred on the axis of rotation)
//   n   number of copies, >= 1 (rounded down to a whole number)
//   ->  position, rotated into the copy that straddles +x
//   cost: an atan, a sin and a cos
//   e.g. vec3 q = p;
//        q.xz = kit_op_repeat_polar(p.xz, 8.0);                         // 8 copies
//        float spokes = kit_sd_box(q - vec3(1.0, 0.0, 0.0), vec3(0.3, 0.1, 0.1));
vec2 kit_op_repeat_polar(vec2 p, float n) {
    if (p.x == 0.0 && p.y == 0.0) return p;   // atan(0, 0) is undefined
    float m = max(floor(n), 1.0);
    float cell = 6.28318531 / m;
    float a = atan(p.y, p.x);
    a -= cell * floor(a / cell + 0.5);
    return length(p) * vec2(cos(a), sin(a));
}
