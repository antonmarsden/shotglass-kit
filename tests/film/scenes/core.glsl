// Exercises core/: noise, colour, eases. Clouds drift over a palette sky.
#include <kit/ease.glsl>
#include <kit/noise.glsl>
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv * vec2(iResolution.x / iResolution.y, 1.0);

    float rise = kit_ease_smoother(kit_tween(0.0, 1.5, iShotTime));
    vec3 sky = kit_palette(uv.y * 0.6 + 0.2 * rise, vec3(0.5), vec3(0.5),
                           vec3(1.0), vec3(0.0, 0.1, 0.2));
    sky = kit_srgb_decode(sky);

    float clouds = kit_fbm(p * 3.0 + vec2(iTime * 0.2, 0.0), 5);
    float detail = 0.5 + 0.5 * kit_gradient_noise(p * 12.0);
    float wisps = kit_value_noise(vec3(p * 5.0, iTime * 0.5));
    float c = smoothstep(0.45, 0.75, clouds * 0.8 + 0.1 * detail + 0.1 * wisps);

    vec3 col = mix(sky, vec3(1.6), c);                    // linear light
    col = kit_srgb_encode(kit_aces(col));
    col *= kit_vignette(uv, 0.35, 0.7);
    col = kit_grain(col, fragCoord, iFrame, 0.03);
    // the remaining eases and hashes, so every function is compiled and used
    float e = kit_ease_linear(0.5) + kit_ease_smooth(0.5) + kit_ease_in(0.5)
            + kit_ease_out(0.5) + kit_ease_inout(0.5) + kit_ease_step(0.5);
    float h = kit_hash(1) + kit_hash(vec2(1.0)) + kit_hash(vec3(1.0)) + kit_hash(ivec2(1)) * 0.0;
    col += 1e-6 * (e + h);
    fragColor = vec4(col, 1.0);
}
