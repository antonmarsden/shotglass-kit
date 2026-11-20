// Exercises core/sdf.glsl: a 2D cartoon of blobs, boxes and a repeated border.
#include <kit/sdf.glsl>
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
    float px = 1.5 / iResolution.y;                        // one pixel, for anti-aliasing

    vec2 bob = vec2(0.0, 0.05 * sin(iShotTime * 3.0));
    float body = kit_op_smin(kit_sd_circle(p - bob, 0.2),
                             kit_sd_box(p - vec2(0.25, -0.1), vec2(0.15, 0.08)), 0.08);
    body = kit_op_subtract(body, kit_sd_circle(p - bob - vec2(-0.06, 0.06), 0.035));
    float outline = kit_op_onion(body, 0.006);
    float limb = kit_op_round(kit_sd_segment(p, vec2(-0.15, -0.15), vec2(-0.35, -0.3)), 0.02);
    vec2 tile = kit_op_repeat(p, vec2(0.12));
    float border = kit_op_intersect(kit_sd_box(tile, vec2(0.02)), -(abs(p.y) - 0.42));
    float shape = kit_op_union(kit_op_smax(body, -1.0, 0.0), limb);

    vec3 col = vec3(0.95, 0.9, 0.8);
    col = mix(col, vec3(0.85, 0.4, 0.3), 1.0 - smoothstep(0.0, px, shape));
    col = mix(col, vec3(0.1), 1.0 - smoothstep(0.0, px, min(outline, border)));

    // 3D shapes evaluated once, so every function is compiled and used
    vec3 q = vec3(p, 0.5);
    float d3 = kit_sd_sphere(q, 0.3) + kit_sd_box(q, vec3(0.2)) + kit_sd_round_box(q, vec3(0.2), 0.05)
             + kit_sd_capsule(q, vec3(0.0), vec3(0.0, 1.0, 0.0), 0.1) + kit_sd_cylinder(q, 0.2, 0.3)
             + kit_sd_plane(q, vec3(0.0, 1.0, 0.0), 1.0) + kit_sd_ellipsoid(q, vec3(0.3, 0.2, 0.1));
    vec3 rq = kit_op_repeat(q, vec3(1.0));
    col += 1e-6 * (d3 + rq.x);
    fragColor = vec4(col * kit_vignette(uv, 0.2, 0.5), 1.0);
}
