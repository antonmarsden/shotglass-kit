// A dark street at night for the light painting: deep blue sky, a few distant
// windows, a wet road catching a little light.
#include <kit/noise.glsl>
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    vec2 p = vec2(uv.x * aspect, uv.y);
    vec3 sky = mix(vec3(0.010, 0.012, 0.030), vec3(0.002, 0.003, 0.010), uv.y);
    // Skyline: blocks of buildings with lit windows.
    float bx = floor(p.x * 9.0);
    float top = 0.22 + 0.16 * kit_hash(int(bx) + 17);
    vec3 col = sky;
    if (uv.y < top) {
        col = vec3(0.004, 0.004, 0.008);
        vec2 w = vec2(p.x * 90.0, p.y * 60.0);
        float lit = step(0.86, kit_hash(ivec2(floor(w)) + ivec2(3, 9)));
        vec2 f = fract(w);
        float pane = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.7);
        col += vec3(0.30, 0.20, 0.08) * lit * pane * smoothstep(0.08, 0.14, uv.y);
    }
    // Road: a dark reflective strip.
    if (uv.y < 0.08) col = vec3(0.006, 0.006, 0.010) + 0.02 * vec3(0.3, 0.25, 0.4) * kit_value_noise(p * vec2(4.0, 40.0));
    col = kit_srgb_encode(col * kit_vignette(uv, 0.4, 0.7));
    fragColor = vec4(col, 1.0);
}
