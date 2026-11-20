// A little house at nightfall: the windows light up one after the other and smoke
// puffs from the chimney. A 2D cartoon from core/sdf.glsl (circle, box, segment and
// every operator), timed with core/ease.glsl.
#include <kit/ease.glsl>
#include <kit/noise.glsl>
#include <kit/color.glsl>
#include <kit/sdf.glsl>

const vec3 INK = vec3(0.13, 0.10, 0.13);

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

// Fill a shape (distance d) and draw its outline, anti-aliased over a pixel.
vec3 draw(vec3 col, float d, vec3 fill, float px) {
    col = mix(col, fill, 1.0 - smoothstep(-px, px, d));
    return mix(col, INK, 1.0 - smoothstep(-px, px, kit_op_onion(d, 0.004)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;   // y up, frame height 1
    float px = 1.0 / iResolution.y;
    float night = kit_ease_inout(iShotProgress);

    // Evening sky and a crescent moon.
    vec3 col = mix(mix(vec3(0.98, 0.80, 0.62), vec3(0.55, 0.60, 0.85), uv.y),
                   mix(vec3(0.42, 0.36, 0.55), vec3(0.12, 0.14, 0.32), uv.y), night);
    float moon = kit_op_subtract(kit_sd_circle(p - vec2(-0.55, 0.30), 0.07),
                                 kit_sd_circle(p - vec2(-0.515, 0.325), 0.06));
    col = mix(col, vec3(1.0, 0.96, 0.80), (1.0 - smoothstep(-px, px, moon)) * (0.4 + 0.6 * night));

    // Ground, and a fence behind the house: posts every 7 cm and a rail.
    col = mix(col, mix(vec3(0.55, 0.72, 0.38), vec3(0.20, 0.30, 0.22), night),
              1.0 - smoothstep(-px, px, p.y + 0.30));
    vec2 post = kit_op_repeat(p - vec2(0.0, -0.26), vec2(0.07, 10.0));
    float fence = kit_op_union(kit_sd_box(post, vec2(0.007, 0.04)),
                               kit_sd_box(p - vec2(0.0, -0.25), vec2(2.0, 0.005)));
    col = mix(col, mix(vec3(0.85, 0.80, 0.70), vec3(0.40, 0.38, 0.40), night),
              1.0 - smoothstep(-px, px, fence));

    // Chimney, and smoke puffs that rise, drift right and grow, merging smoothly.
    col = draw(col, kit_sd_box(p - vec2(0.15, 0.25), vec2(0.03, 0.09)), vec3(0.65, 0.35, 0.30), px);
    float smoke = 1e9;
    for (int i = 0; i < 6; i++) {
        float t = fract(iTime * 0.3 + float(i) / 6.0);
        float rise = kit_ease_out(t);
        vec2 at = vec2(0.15 + 0.08 * rise + 0.02 * kit_gradient_noise(vec2(t * 3.0, float(i))),
                       0.36 + 0.28 * rise);
        smoke = kit_op_smin(smoke, kit_sd_circle(p - at, mix(0.015, 0.05, t)), 0.03);
    }
    float fadeOut = 1.0 - smoothstep(0.45, 0.66, p.y);
    col = mix(col, mix(vec3(0.95), vec3(0.60, 0.60, 0.70), night),
              (1.0 - smoothstep(-px, px, smoke)) * 0.85 * fadeOut);

    // Walls.
    float wall = kit_sd_box(p - vec2(0.0, -0.12), vec2(0.25, 0.18));
    col = draw(col, wall, mix(vec3(0.97, 0.88, 0.70), vec3(0.55, 0.50, 0.50), night), px);

    // Two windows (one shape, repeated, kept inside the wall). Lights go on in turn.
    vec2 w = kit_op_repeat(p - vec2(0.14, -0.06), vec2(0.28, 10.0));
    float which = floor((p.x - 0.14) / 0.28 + 0.5);                 // -1 left, 0 right
    float on = kit_ease_step(kit_tween(0.0, 0.7 + 0.6 * (which + 1.0), iShotTime));
    float pane = kit_op_intersect(kit_sd_box(w, vec2(0.05)), wall);
    vec3 glow = vec3(1.0, 0.82, 0.40);
    col += glow * 0.35 * on * exp(-25.0 * max(pane, 0.0)) * (1.0 - smoothstep(-px, px, wall));
    col = draw(col, pane, mix(vec3(0.25, 0.30, 0.45), glow, on), px);
    float bars = kit_op_round(min(kit_sd_segment(w, vec2(-0.05, 0.0), vec2(0.05, 0.0)),
                                  kit_sd_segment(w, vec2(0.0, -0.05), vec2(0.0, 0.05))), 0.004);
    col = mix(col, INK, 1.0 - smoothstep(-px, px, kit_op_intersect(bars, pane)));

    // Door with a knob.
    col = draw(col, kit_op_round(kit_sd_box(p - vec2(0.0, -0.22), vec2(0.04, 0.07)), 0.01),
               vec3(0.45, 0.28, 0.22), px);
    col = mix(col, INK, 1.0 - smoothstep(-px, px, kit_sd_circle(p - vec2(0.03, -0.22), 0.008)));

    // Roof: a square turned 45 degrees, cut along the top of the walls.
    float diamond = kit_sd_box(rot(0.785398) * (p - vec2(0.0, 0.06)), vec2(0.24));
    float roof = kit_op_round(kit_op_smax(diamond, 0.06 - p.y, 0.01), 0.006);
    col = draw(col, roof, mix(vec3(0.80, 0.30, 0.25), vec3(0.40, 0.18, 0.20), night), px);

    col *= kit_vignette(uv, 0.30, 0.60);
    col = kit_grain(col, fragCoord, iFrame, 0.02);
    fragColor = vec4(col, 1.0);
}
