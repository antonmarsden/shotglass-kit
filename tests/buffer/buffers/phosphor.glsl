// A green-screen monitor's phosphor: the Life cells (iChannel1) drawn as rounded
// glowing blocks, kept over the previous glow (iChannel0) with a separate half-life
// per channel (kit_buf_decay): green lingers, the white-hot core fades fast, like a
// P1 phosphor. State: linear light.
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 cells = vec2(textureSize(iChannel1, 0));
    vec2 c = uv * cells;
    float on = kit_buf_fetch(iChannel1, ivec2(floor(c)), true).r;
    vec2 f = abs(fract(c) - 0.5);
    float block = 1.0 - smoothstep(0.30, 0.42, max(f.x, f.y));
    float e = on * block;
    vec4 elem = vec4(0.5 * e, 1.6 * e, 0.6 * e, 0.0);
    // Green halves every 0.35 s (kit_buf_trail); red and blue are pre-scaled to their
    // own, shorter half-lives.
    float g = kit_buf_decay(0.35, iTimeDelta);
    vec4 tint = vec4(kit_buf_decay(0.05, iTimeDelta) / g, 1.0, kit_buf_decay(0.08, iTimeDelta) / g, 0.0);
    vec4 prev = kit_buf_fetch(iChannel0, ivec2(fragCoord), false);
    fragColor = kit_buf_trail(prev * tint, elem, 0.35, iTimeDelta);
}
