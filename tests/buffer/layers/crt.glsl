// An old terminal on a desk, raymarched (core/raymarch.glsl, camera.glsl, sdf.glsl):
// a beige case with rounded edges and a deep back, the curved glass of the tube bulging
// out of a recessed bezel, a wooden desk, a dim room lamp. The tube shows the phosphor
// buffer (iChannel0): each ray that hits the glass reads the phosphor where it hits, so
// the picture wraps round the curve, with scanlines, darker corners where the tube
// turns away, and the room's lamp reflected more strongly towards the edges (Fresnel).
// The screen lights the bezel and the desk green, with the phosphor's average glow.
// The camera starts at a three-quarter view and pushes slowly in.
#include <kit/sdf.glsl>
#include <kit/raymarch.glsl>
#include <kit/camera.glsl>
#include <kit/noise.glsl>
#include <kit/color.glsl>
#include <buffer/sample.glsl>

const vec3 TUBE_C = vec3(0.0, 0.03, -0.9);   // centre of the glass's sphere
const float TUBE_R = 1.19;                   // its radius: the apex is at z = 0.29
const vec2 OPEN = vec2(0.32, 0.245);         // half-size of the screen opening
const vec3 LAMP = vec3(-1.6, 1.4, 1.2);      // the room lamp

float sd_case(vec3 p) {
    float body = kit_sd_round_box(p, vec3(0.42, 0.36, 0.30), 0.05);
    float back = kit_sd_round_box(p - vec3(0.0, -0.01, -0.36), vec3(0.32, 0.29, 0.22), 0.09);
    float d = kit_op_smin(body, back, 0.06);
    // The recess round the tube, with a bevelled edge.
    float recess = kit_sd_round_box(p - vec3(0.0, 0.03, 0.31), vec3(OPEN + 0.035, 0.07), 0.035);
    return kit_op_smax(d, -recess, 0.015);
}

float sd_tube(vec3 p) {
    float glass = length(p - TUBE_C) - TUBE_R;
    float frame = kit_sd_round_box(p - vec3(0.0, 0.03, 0.0), vec3(OPEN, 0.6), 0.04);
    return max(glass, frame);
}

float sd_desk(vec3 p) { return kit_sd_plane(p, vec3(0.0, 1.0, 0.0), 0.37); }

float kit_scene(vec3 p) { return min(min(sd_case(p), sd_tube(p)), sd_desk(p)); }

// Which surface p is on: 0 case, 1 tube, 2 desk.
int material(vec3 p) {
    float c = sd_case(p), t = sd_tube(p), d = sd_desk(p);
    if (t < c && t < d) return 1;
    return d < c ? 2 : 0;
}

// The screen's picture at a point on the glass: the phosphor, scanlines, corners.
vec3 screen(vec3 p) {
    vec2 s = (p.xy - vec2(0.0, 0.03)) / OPEN;        // -1..1 across the opening
    vec2 su = s * 0.5 + 0.5;
    vec2 size = vec2(textureSize(iChannel0, 0));
    vec3 glow = kit_buf_sample(iChannel0, su, false).rgb;
    vec3 bloom = kit_buf_box(iChannel0, ivec2(su * size), false).rgb;
    float scan = 0.7 + 0.3 * sin(su.y * size.y * 6.28318531);
    float corner = 1.0 - smoothstep(0.75, 1.15, length(s * vec2(0.85, 1.0)));
    return (vec3(0.004, 0.010, 0.006) + glow * scan + 0.3 * bloom) * (0.35 + 0.65 * corner);
}

// The phosphor's average glow: the light the screen throws on the room.
vec3 screen_light() {
    vec3 sum = vec3(0.0);
    for (int i = 0; i < 9; i++) {
        vec2 q = vec2(float(i % 3), float(i / 3)) * 0.33 + 0.17;
        sum += kit_buf_box(iChannel0, ivec2(q * vec2(textureSize(iChannel0, 0))), false).rgb;
    }
    return sum / 9.0;
}

// The dim room, seen in reflections and behind the desk: a warm lamp up to the left.
vec3 room(vec3 rd) {
    vec3 l = normalize(LAMP);
    float lamp = pow(max(dot(rd, l), 0.0), 200.0) * 6.0 + pow(max(dot(rd, l), 0.0), 8.0) * 0.08;
    // A dim window up to the right: a soft rectangle of cool light, which the curved
    // glass bends into a long highlight.
    vec3 w = normalize(vec3(1.2, 0.9, 1.0));
    vec3 wx = normalize(cross(w, vec3(0.0, 1.0, 0.0)));
    vec3 wy = cross(wx, w);
    vec2 wq = vec2(dot(rd, wx), dot(rd, wy)) / max(dot(rd, w), 1e-3);
    float window = (1.0 - smoothstep(0.45, 0.55, abs(wq.x))) * (1.0 - smoothstep(0.55, 0.65, abs(wq.y))) * step(0.0, dot(rd, w));
    vec3 cool = vec3(0.35, 0.45, 0.6) * 0.6 * window;
    return vec3(0.012, 0.010, 0.010) * (0.6 + 0.4 * rd.y) + vec3(1.0, 0.75, 0.45) * lamp + cool;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime;
    vec3 ta = vec3(0.0, 0.0, 0.05);
    float dist = mix(2.2, 1.75, smoothstep(0.0, 4.0, t));
    vec3 ro = kit_cam_orbit(ta, vec2(-0.55 + 0.05 * t, 0.16), dist);
    mat3 cam = kit_cam_look_at(ro, ta, 0.0);
    vec3 rd = kit_cam_ray(cam, fragCoord, iResolution.xy, 0.7);

    vec3 col = room(rd);
    float hit = kit_raymarch(ro, rd, 160, 0.0008, 8.0);
    if (hit >= 0.0) {
        vec3 p = ro + rd * hit;
        vec3 n = kit_normal(p, 0.0008);
        int m = material(p);
        vec3 l = normalize(LAMP - p);
        vec3 glow = screen_light();
        // The screen as a light: from its centre, towards whatever faces it.
        vec3 sc = vec3(0.0, 0.03, 0.3);
        vec3 ls = sc - p;
        float ds = length(ls);
        ls /= ds;
        float facing = max(dot(-ls, vec3(0.0, 0.0, 1.0)), 0.0);
        vec3 green = glow * 2.5 * max(dot(n, ls), 0.0) * facing / (1.0 + 6.0 * ds * ds);
        if (m == 1) {
            float f = 0.04 + 0.96 * pow(1.0 - max(dot(n, -rd), 0.0), 5.0);
            col = 0.75 * screen(p) * (1.0 - f) + room(reflect(rd, n)) * (f + 0.06);
        } else {
            vec3 albedo = m == 2
                ? vec3(0.07, 0.035, 0.018) * (0.7 + 0.3 * kit_value_noise(p.xz * vec2(4.0, 60.0)))
                : vec3(0.52, 0.46, 0.36);
            float sh = kit_soft_shadow(p + n * 0.002, l, 0.01, 3.0, 12.0);
            float ao = kit_ao(p, n, 0.08);
            float diff = max(dot(n, l), 0.0) * sh;
            float spec = pow(max(dot(reflect(-l, n), -rd), 0.0), m == 2 ? 30.0 : 12.0) * sh;
            vec3 lamp = vec3(1.0, 0.8, 0.55) * 0.9;
            col = albedo * (lamp * diff + vec3(0.03) * ao + green) + lamp * spec * (m == 2 ? 0.06 : 0.08);
            if (m == 2) col = mix(col, room(rd), smoothstep(2.0, 4.0, hit));   // the desk fades into the dark
        }
    }
    col *= kit_vignette(uv, 0.4, 0.7);
    fragColor = vec4(kit_srgb_encode(kit_aces(col * 1.4)), 1.0);
}
