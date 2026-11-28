// Ink on the paper (iChannel0): B of the reaction-diffusion (iChannel1, bilinear) as
// pigment density, multiplied into the paper like a wash, darker where it pools
// (B high) and with a faint bleed halo (a wider blur of B).
#include <kit/color.glsl>
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 paper = kit_srgb_decode(texture(iChannel0, uv).rgb);
    float b = kit_buf_sample(iChannel1, uv, false).y;
    vec2 size = vec2(textureSize(iChannel1, 0));
    float halo = kit_buf_blur(iChannel1, ivec2(uv * size), false).y;
    float ink = smoothstep(0.08, 0.35, b);
    float wash = smoothstep(0.02, 0.3, halo) * 0.25;
    vec3 pigment = mix(vec3(0.35, 0.45, 0.75), vec3(0.05, 0.08, 0.30), smoothstep(0.2, 0.45, b));
    vec3 col = paper * mix(vec3(1.0), pigment, max(ink, wash));
    fragColor = vec4(kit_srgb_encode(col), 1.0);
}
