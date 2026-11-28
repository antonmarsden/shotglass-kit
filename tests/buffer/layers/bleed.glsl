// The ink on the paper (iChannel0): pigment from the flow (iChannel1: x water, y in
// suspension, z settled) absorbing light like a dye, per channel (an indigo ink takes
// out red and green first, so thin washes go blue and dense pools near black). Settled
// pigment granulates a little with the paper's tooth; wet paper looks a touch darker
// and glossier.
#include <kit/noise.glsl>
#include <kit/color.glsl>
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = fragCoord / iResolution.y;
    vec3 paper = kit_srgb_decode(texture(iChannel0, uv).rgb);
    vec4 s = kit_buf_sample(iChannel1, uv, false);
    float tooth = kit_value_noise(p * 300.0);
    float pigment = s.z * (0.85 + 0.3 * tooth) + 0.8 * s.y;
    vec3 absorb = vec3(2.6, 2.0, 0.7);
    vec3 col = paper * exp(-absorb * pigment);
    float wet = smoothstep(0.05, 0.4, s.x);
    col *= 1.0 - 0.08 * wet;
    fragColor = vec4(kit_srgb_encode(col), 1.0);
}
