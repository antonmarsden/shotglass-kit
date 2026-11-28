// A petri dish seen from above on a dark bench, lit from the upper left: amber agar,
// the culture growing on it (B of the reaction-diffusion, iChannel1, bilinear) as a
// creamy, slightly raised colony with a soft shadow on its lower right edge, inside a
// glass wall that catches a rim highlight and throws a faint shadow on the bench.
// The scene (iChannel0) is not used: the dish fills the frame.
#include <kit/noise.glsl>
#include <kit/color.glsl>
#include <buffer/sample.glsl>

const float DISH = 0.42;     // agar radius, frame heights (as in buffers/rd.glsl)
const float WALL = 0.025;    // glass wall thickness

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 q = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float px = 1.0 / iResolution.y;
    float r = length(q);
    vec2 light = normalize(vec2(-0.6, 0.8));

    // The bench: dark matte, a soft pool of light, the dish's shadow to the lower right.
    vec3 col = vec3(0.035, 0.037, 0.04) * (1.2 - 0.6 * length(q - vec2(-0.2, 0.25)));
    col *= 0.9 + 0.1 * kit_value_noise(fragCoord * 0.5);
    float shadow = 1.0 - smoothstep(DISH + WALL - 0.02, DISH + WALL + 0.06, length(q + 0.03 * light));
    col *= 1.0 - 0.6 * shadow;

    // The agar: translucent amber, a little brighter towards the light.
    vec3 agar = vec3(0.62, 0.42, 0.16) * (0.85 + 0.25 * dot(q / DISH, light));
    // The colony: B as density; its height is shaded from the gradient of B.
    vec2 size = vec2(textureSize(iChannel1, 0));
    float b = kit_buf_sample(iChannel1, uv, false).y;
    // Gradient from bilinear samples one texel apart, so the shading is as smooth as B
    // itself (a texel-centred gradient would step in blocks of one texel).
    vec2 tx = 1.0 / size;
    vec2 g = 0.5 * vec2(kit_buf_sample(iChannel1, uv + vec2(tx.x, 0.0), false).y - kit_buf_sample(iChannel1, uv - vec2(tx.x, 0.0), false).y,
                        kit_buf_sample(iChannel1, uv + vec2(0.0, tx.y), false).y - kit_buf_sample(iChannel1, uv - vec2(0.0, tx.y), false).y);
    // Wide edge ramp: the grid is coarse, so a sharp threshold would show its texels.
    float cover = smoothstep(0.05, 0.35, b) * (1.0 - smoothstep(DISH - 0.03, DISH - 0.005, r));
    float relief = clamp(0.5 + 3.0 * dot(-g, light), 0.0, 1.0);
    vec3 colony = mix(vec3(0.80, 0.74, 0.58), vec3(0.95, 0.90, 0.78), smoothstep(0.2, 0.45, b));
    colony *= 0.75 + 0.5 * relief;
    float halo = kit_buf_blur(iChannel1, ivec2(uv * size), false).y;
    vec3 inside = agar * (1.0 - 0.25 * smoothstep(0.02, 0.3, halo)) ;
    inside = mix(inside, colony, cover);
    // Agar darkens into a meniscus where it meets the wall.
    inside *= 1.0 - 0.35 * smoothstep(DISH - 0.05, DISH, r);
    col = mix(col, inside, 1.0 - smoothstep(DISH - px, DISH + px, r));

    // The glass wall: a thin ring, bright where it faces the light, a dimmer one opposite.
    float ring = smoothstep(DISH - px, DISH + px, r) * (1.0 - smoothstep(DISH + WALL - px, DISH + WALL + px, r));
    float face = dot(q / max(r, 1e-4), light);
    float rim = exp2(-pow((r - DISH - 0.5 * WALL) / (0.25 * WALL), 2.0));
    vec3 glass = vec3(0.10, 0.11, 0.12) + vec3(0.45, 0.46, 0.5) * rim * (0.1 + 0.9 * smoothstep(0.3, 1.0, face))
               + vec3(0.1) * rim * smoothstep(0.6, 1.0, -face);
    col = mix(col, glass, ring);
    // A soft highlight on the lid across the upper left.
    float sheen = exp2(-pow(length(q - vec2(-0.16, 0.18)) / 0.12, 2.0)) * (1.0 - smoothstep(DISH, DISH + WALL, r));
    col += vec3(0.05) * sheen;

    col *= kit_vignette(uv, 0.4, 0.7);
    fragColor = vec4(kit_srgb_encode(col), 1.0);
}
