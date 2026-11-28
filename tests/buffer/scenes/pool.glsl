// The floor of a swimming pool: pale tiles with dark grout under blue water, and
// slow caustic light.
#include <kit/noise.glsl>
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = fragCoord / iResolution.y;
    vec2 t = p * 9.0;
    vec2 f = fract(t);
    float grout = smoothstep(0.0, 0.06, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
    float shade = 0.9 + 0.1 * kit_hash(ivec2(floor(t)));
    vec3 tile = mix(vec3(0.05, 0.18, 0.28), vec3(0.55, 0.85, 0.95) * shade, grout);
    // A lane line.
    if (abs(p.y - 0.5) < 0.04) tile *= vec3(0.25, 0.3, 0.6);
    vec2 cell = kit_cellular_noise(p * 5.0 + vec2(0.3, 0.2) * iTime);
    float caustic = pow(clamp(1.0 - (cell.y - cell.x) * 3.0, 0.0, 1.0), 4.0);
    vec3 col = tile * vec3(0.35, 0.75, 0.9) + 0.25 * caustic * vec3(0.8, 1.0, 1.0);
    fragColor = vec4(kit_srgb_encode(col * kit_vignette(uv, 0.3, 0.8)), 1.0);
}
