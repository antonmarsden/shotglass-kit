// Dusk over rolling hills: the sun sets, clouds drift, stars come out.
// Uses core/: ease, noise (hash, value, gradient, simplex, fbm), color (palette, sRGB, ACES,
// vignette, grain) and sdf (the sun).
#include <kit/ease.glsl>
#include <kit/noise.glsl>
#include <kit/color.glsl>
#include <kit/sdf.glsl>

// Colours are picked in sRGB and mixed in linear light.
vec3 srgb(float r, float g, float b) { return kit_srgb_decode(vec3(r, g, b)); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    vec2 p = vec2(uv.x * aspect, uv.y);
    float px = 1.0 / iResolution.y;
    float dusk = kit_ease_smoother(iShotProgress);

    // Sky: warm at the horizon, blue above, both darkening as the sun goes down.
    vec3 low = mix(srgb(1.0, 0.62, 0.35), srgb(0.80, 0.38, 0.42), dusk);
    vec3 high = mix(srgb(0.35, 0.52, 0.85), srgb(0.10, 0.12, 0.32), dusk);
    vec3 col = mix(low, high, kit_ease_out(uv.y));

    // Stars fade in as it gets dark, each twinkling on its own.
    vec2 sp = p * 90.0;
    ivec2 cell = ivec2(floor(sp));
    float star = step(0.993, kit_hash(cell))
               * (1.0 - smoothstep(0.0, 0.3, length(fract(sp) - 0.5)));
    float twinkle = 0.5 + 0.5 * kit_value_noise(vec3(vec2(cell), iTime * 3.0));
    col += vec3(star * twinkle) * kit_ease_in(dusk) * smoothstep(0.45, 0.85, uv.y);

    // The sun, sinking behind the hills, with a glow around it.
    vec2 sunAt = vec2(0.62 * aspect, mix(0.48, 0.18, dusk));
    float sun = kit_sd_circle(p - sunAt, 0.07);
    col += srgb(1.0, 0.70, 0.40) * 0.6 * exp(-7.0 * max(sun, 0.0)) * (1.0 - 0.5 * dusk);
    col = mix(col, srgb(1.0, 0.93, 0.75) * 1.8, 1.0 - smoothstep(-px, px, sun));

    // Clouds: stretched fbm, gently churning, lit pink then purple.
    float c = kit_fbm(p * vec2(1.4, 4.5) + vec2(iTime * 0.04, 0.0), 5);
    c *= 0.9 + 0.2 * kit_value_noise(vec3(p * 5.0, iTime * 0.2));
    c += 0.03 * kit_simplex_noise(p * 9.0 + vec2(iTime * 0.3, 0.0));  // wispy edges
    float cloud = smoothstep(0.46, 0.66, c) * smoothstep(0.38, 0.60, uv.y);
    col = mix(col, mix(srgb(1.0, 0.75, 0.65), srgb(0.50, 0.32, 0.50), dusk), cloud * 0.8);

    // Three layers of hills, far (hazy) to near (dark).
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float h = 0.34 - 0.09 * fi
                + 0.06 * kit_gradient_noise(vec2(p.x * (1.2 + 0.8 * fi) + 7.0 * fi, fi));
        // greens from a palette ramp: far hills lighter and bluer, near ones deeper
        vec3 green = kit_srgb_decode(kit_palette(0.55 + 0.08 * fi, vec3(0.38, 0.55, 0.35),
                                                 vec3(0.10, 0.12, 0.10), vec3(1.0),
                                                 vec3(0.10, 0.0, 0.25)));
        vec3 haze = mix(low, high, 0.6);                    // distance turns things bluer
        vec3 tint = mix(green, haze, 0.45 * (1.0 - 0.5 * fi) * (1.0 - 0.5 * fi))
                  * mix(1.0, 0.30, dusk) * (1.0 - 0.2 * fi);
        col = mix(col, tint, 1.0 - smoothstep(-px, px, p.y - h));
    }

    // Mist settling in the valleys.
    float mist = kit_fbm(vec3(p * vec2(2.0, 7.0), iTime * 0.1), 4);
    vec3 mistColor = mix(srgb(0.85, 0.85, 0.90), low, 0.3) * mix(1.0, 0.4, dusk);
    col = mix(col, mistColor, mist * 0.3 * smoothstep(0.25, 0.02, uv.y));

    col = kit_srgb_encode(kit_aces(col * 1.3));
    col *= kit_vignette(uv, 0.35, 0.65);
    col = kit_grain(col, fragCoord, iFrame, 0.025);
    fragColor = vec4(col, 1.0);
}
