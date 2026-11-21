// A ring of pillars round a ball, filmed by a camera that movie.toml moves: every
// function in core/camera.glsl, driven by keyframed uniforms.
//   uOrbit     vec2   yaw and pitch round the ball, radians      (kit_cam_orbit)
//   uDist      float  orbit distance                              (kit_cam_orbit)
//   uDolly     float  how far to dolly in from there              (kit_cam_dolly)
//   uRoll      float  camera roll, radians                        (kit_cam_look_at)
//   uVertigo   float  0..1: 0 a fixed lens, 1 a dolly zoom that keeps the ball the
//                     same size                                   (kit_cam_dolly_zoom)
//   uAperture  float  lens radius; 0 is a pinhole                 (kit_cam_dof)
#include <kit/camera.glsl>
#include <kit/noise.glsl>
#include <kit/color.glsl>
#include <kit/sdf.glsl>

const vec3 TARGET = vec3(0.0, 0.5, 0.0);
const float FOV = 0.7;
const int LENS_SAMPLES = 8;

vec2 nearest(vec2 a, vec2 b) { return a.x < b.x ? a : b; }   // (distance, material)

vec2 scene(vec3 p) {
    vec2 d = vec2(kit_sd_plane(p, vec3(0.0, 1.0, 0.0), 0.0), 0.0);
    d = nearest(d, vec2(kit_sd_sphere(p - TARGET, 0.5), 1.0));
    // eight pillars on a circle of radius 2.2, then a grid of far ones every 3 units
    float a = 0.78539816 * floor(atan(p.z, p.x) / 0.78539816 + 0.5);
    vec3 q = p - vec3(2.2 * cos(a), 0.0, 2.2 * sin(a));
    d = nearest(d, vec2(kit_sd_cylinder(q - vec3(0.0, 0.6, 0.0), 0.15, 0.6), 2.0));
    vec3 g = p;
    g.xz = kit_op_repeat(p.xz, vec2(3.0));
    float far = kit_op_subtract(kit_sd_box(g - vec3(0.0, 1.0, 0.0), vec3(0.2, 1.0, 0.2)),
                                 length(p.xz) - 10.5);   // only well outside the ring
    d = nearest(d, vec2(far, 3.0));
    return d;
}

vec3 normalAt(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(scene(p + e.xyy).x - scene(p - e.xyy).x,
                          scene(p + e.yxy).x - scene(p - e.yxy).x,
                          scene(p + e.yyx).x - scene(p - e.yyx).x));
}

vec3 shade(vec3 ro, vec3 rd, vec3 bg) {
    float t = 0.0;
    vec2 hit = vec2(1e9, -1.0);
    for (int i = 0; i < 100; i++) {
        hit = scene(ro + rd * t);
        if (hit.x < 0.0005 * t || t > 30.0) break;
        t += hit.x;
    }
    if (t > 30.0) return bg;
    vec3 p = ro + rd * t;
    vec3 n = normalAt(p);
    vec3 sun = normalize(vec3(0.6, 0.8, 0.3));
    vec3 base;
    if (hit.y < 0.5) {
        vec2 c = floor(p.xz * 2.0);
        base = mix(vec3(0.75), vec3(0.25), mod(c.x + c.y, 2.0));
    } else if (hit.y < 1.5) {
        base = vec3(0.9, 0.25, 0.1);
    } else if (hit.y < 2.5) {
        base = vec3(0.2, 0.45, 0.85);
    } else {
        base = vec3(0.7, 0.65, 0.55);
    }
    float diff = max(dot(n, sun), 0.0);
    float ao = clamp(scene(p + n * 0.1).x / 0.1, 0.0, 1.0);
    vec3 col = base * (1.3 * diff + vec3(0.3, 0.35, 0.45) * (0.4 + 0.6 * ao));
    return mix(col, bg, 1.0 - exp(-0.0008 * t * t));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec3 ro = kit_cam_orbit(TARGET, uOrbit, uDist);
    ro = kit_cam_dolly(ro, TARGET, uDolly);
    float fov = mix(FOV, kit_cam_dolly_zoom(FOV, uDist, length(TARGET - ro)), uVertigo);
    mat3 cam = kit_cam_look_at(ro, TARGET, uRoll);
    float focus = dot(TARGET - ro, cam[2]);   // keep the ball sharp

    vec3 bg = mix(vec3(0.85, 0.85, 0.9), vec3(0.45, 0.6, 0.85), uv.y);
    // Stratified lens samples, rotated by a per-pixel random amount.
    vec2 h = vec2(kit_hash(ivec3(ivec2(fragCoord), 0)), kit_hash(ivec3(ivec2(fragCoord), 1)));
    vec3 col = vec3(0.0);
    for (int i = 0; i < LENS_SAMPLES; i++) {
        vec3 o = ro;
        vec3 rd = kit_cam_ray(cam, fragCoord, iResolution.xy, fov);
        vec2 xi = vec2((float(i) + h.x) / float(LENS_SAMPLES), fract(h.y + 0.61803399 * float(i)));
        kit_cam_dof(o, rd, cam, uAperture, focus, xi);
        col += shade(o, rd, bg);
    }
    col /= float(LENS_SAMPLES);

    col = kit_srgb_encode(kit_aces(col));
    fragColor = vec4(col, 1.0);
}
