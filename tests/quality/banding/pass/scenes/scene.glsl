#include <kit/noise.glsl>

// A slow grey ramp, 0.3 to 0.4 across the frame: about 25 8-bit levels, dithered with a one-level triangular hash so no flat runs are left.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float v = mix(0.3, 0.4, fragCoord.x / iResolution.x);
    ivec2 c = ivec2(fragCoord);
    v += (kit_hash(c) + kit_hash(c + ivec2(7919, 104729)) - 1.0) / 255.0;
    fragColor = vec4(vec3(v), 1.0);
}
