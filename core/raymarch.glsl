// shotglass-kit/core: raymarch.glsl
//
// Sphere tracing for 3D scenes made of signed distances (sdf.glsl, sdf_ops.glsl):
// find where a ray hits the scene, its normal there, soft shadows and ambient
// occlusion.
//
// GLSL can't pass a function as a parameter, so these all call one function that
// your shader defines, anywhere in the file (before or after this include):
//
//     float kit_scene(vec3 p);   // distance from p to the nearest surface, < 0 inside
//
// It's the one kit_ name you write yourself. A shader that includes this file but
// calls none of these functions doesn't need to define it. One scene per shader: to
// march a second one, write that loop yourself. For materials, look them up again at
// the hit point (one more call to your own scene function per pixel, cheaper than
// carrying them through every step).
//
// The distance must be a true distance or an underestimate of it (a bound), as the
// kit's shapes and operators are; an overestimate makes rays pass through surfaces.
// Lengths (eps, tmax, radii) are in the units of p. Hit distances are along rd, so
// rd must have length 1.
// sound: picture only (it marches a scene; there's nothing for it to do in sound)

float kit_scene(vec3 p);

// kit_raymarch(ro, rd, steps, eps, tmax): sphere-trace from ro along rd and return how
// far along the ray it hit kit_scene's surface, or -1.0 if it didn't.
//   ro     ray origin (the camera), outside the scene's shapes
//   rd     ray direction, length 1
//   steps  most scene evaluations to spend, 1..1024 (clamped); 64..200 is typical:
//          too few and rays that graze an edge give up early (reported as misses)
//   eps    how close counts as a hit, > 0; about a pixel's footprint at the distance
//          that matters, e.g. 0.001 for a scene a few units across
//   tmax   furthest distance to look, > 0
//   ->     distance along rd to the hit (0..tmax), or -1.0 for a miss
//   cost: up to `steps` calls to kit_scene
//   e.g. float t = kit_raymarch(ro, rd, 128, 0.001, 20.0);
//        if (t >= 0.0) { vec3 p = ro + rd * t; /* shade p */ }
float kit_raymarch(vec3 ro, vec3 rd, int steps, float eps, float tmax) {
    int n = clamp(steps, 1, 1024);
    float t = 0.0;
    for (int i = 0; i < n; i++) {
        float d = kit_scene(ro + rd * t);
        if (d < eps) return t;
        t += d;
        if (t > tmax) return -1.0;
    }
    return -1.0;
}

// kit_normal(p, eps): the surface normal of kit_scene at p, from the slope of the
// distance (4 samples at the corners of a tetrahedron, cheaper than 6 on the axes).
//   p    a point on (or very near) the surface, e.g. ro + rd * t from kit_raymarch
//   eps  sample spacing, > 0; about the eps you raymarched with. Bigger smooths
//        away fine detail, too small gives speckled normals from float rounding
//   ->   unit vector pointing out of the surface (zero where the distance is flat)
//   cost: 4 calls to kit_scene
//   e.g. vec3 n = kit_normal(p, 0.001);
vec3 kit_normal(vec3 p, float eps) {
    vec2 k = vec2(1.0, -1.0);
    vec3 n = k.xyy * kit_scene(p + k.xyy * eps)
           + k.yyx * kit_scene(p + k.yyx * eps)
           + k.yxy * kit_scene(p + k.yxy * eps)
           + k.xxx * kit_scene(p + k.xxx * eps);
    return n / max(length(n), 1e-20);
}

// kit_soft_shadow(p, dir, tmin, tmax, k): how much light from direction dir reaches p,
// with soft edges: rays that pass close to a shape count as partly blocked.
//   p     the point being lit, usually lifted off the surface a little (p + n * 0.002)
//   dir   direction towards the light, length 1
//   tmin  start this far from p, > 0, to step clear of p's own surface (e.g. 0.01)
//   tmax  stop this far from p, > tmin (the distance to the light, or the scene's size)
//   k     sharpness, > 0: about 2 (very soft) to 32 (nearly hard); a penumbra this
//         wide is roughly (distance to the blocker) / k
//   ->    0..1: 0 in full shadow, 1 fully lit
//   cost: up to 64 calls to kit_scene
//   e.g. float sh = kit_soft_shadow(p + n * 0.002, sun, 0.01, 10.0, 8.0);
//        col *= 0.3 + 0.7 * sh;
float kit_soft_shadow(vec3 p, vec3 dir, float tmin, float tmax, float k) {
    float span = max(tmax - tmin, 1e-6);
    float res = 1.0;
    float t = tmin;
    for (int i = 0; i < 64; i++) {
        float h = kit_scene(p + dir * t);
        res = min(res, k * h / t);
        if (res < 0.001) break;
        t += clamp(h, span / 256.0, span / 12.0);   // never stall, never skip much
        if (t > tmax) break;
    }
    res = clamp(res, 0.0, 1.0);
    return res * res * (3.0 - 2.0 * res);   // smooth the penumbra's edges
}

// kit_ao(p, n, r): ambient occlusion: how open the space just outside the surface is,
// sampled at 5 points along the normal out to distance r. Darkens creases, corners
// and where shapes meet.
//   p   a point on the surface
//   n   the surface normal at p (kit_normal), length 1
//   r   how far out to look, > 0; about the size of the creases you want to darken
//   ->  0..1: 1 in the open (or on a flat floor), towards 0 deep in a crease
//   cost: 5 calls to kit_scene
//   e.g. float ao = kit_ao(p, n, 0.3);
//        col *= ao;
float kit_ao(vec3 p, vec3 n, float r) {
    float occ = 0.0;
    float w = 1.0;
    for (int i = 1; i <= 5; i++) {
        float h = r * float(i) / 5.0;
        occ += (h - kit_scene(p + n * h)) * w;   // how much nearer the scene is than h
        w *= 0.5;
    }
    // occ / (r * 0.7125) would be 1 with the scene pressed right against every sample;
    // doubling it gives creases visible contrast.
    return clamp(1.0 - 2.0 * occ / (max(r, 1e-6) * 0.7125), 0.0, 1.0);
}
