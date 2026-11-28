// Raindrops on a pool: the damped wave equation (kit_buf_wave) from the state one and
// two frames ago (@prev on iChannel0, frame = -2 on iChannel1). The height, -1..1, is
// stored in rgba8 as 16 bits over red and green (kit_buf_pack_signed, then
// kit_buf_pack16). Both packings are linear in the channels, so the Laplacian of the
// stored channels, weighed, is the Laplacian of the height. A drop lands every 5
// frames at a hashed place (frames since the reset: the same fold however it's reached).
#include <kit/noise.glsl>
#include <buffer/sample.glsl>

float height(vec4 c) {
    return kit_buf_unpack_signed(vec4(kit_buf_unpack16(c.xy)), 1.0).x;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    // Before the first two steps there is no history: still water (black would read -1).
    float cur = iFrame >= 1 ? height(kit_buf_fetch(iChannel0, p, false)) : 0.0;
    float prev = iFrame >= 2 ? height(kit_buf_fetch(iChannel1, p, false)) : 0.0;
    // d height / d channel: 2 * (65280, 255) / 65535 for (red, green).
    vec4 w = vec4(65280.0, 255.0, 0.0, 0.0) * (2.0 / 65535.0);
    float lap = iFrame >= 1 ? dot(kit_buf_laplacian(iChannel0, p, false), w) : 0.0;
    float h = kit_buf_wave(cur, prev, lap, 0.6, 1.2, iTimeDelta);
    if (iFrame % 5 == 0) {
        int k = iFrame / 5;
        float aspect = iResolution.x / iResolution.y;
        vec2 c = vec2(kit_hash(ivec2(k, 31)) * aspect, kit_hash(ivec2(k, 32)));
        float size = 0.02 + 0.015 * kit_hash(ivec2(k, 33));
        h -= 0.5 * kit_buf_drop(fragCoord / iResolution.y, c, size);
    }
    h = clamp(h, -1.0, 1.0);
    vec2 hi = kit_buf_pack16(kit_buf_pack_signed(vec4(h), 1.0).x);
    fragColor = vec4(hi, 0.0, 1.0);
}
