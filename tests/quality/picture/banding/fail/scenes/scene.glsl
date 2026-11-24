#include <kit/noise.glsl>

// A slow grey ramp, 0.3 to 0.4 across the frame: about 25 8-bit levels, undithered, so it shows as bands about 15 pixels wide.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float v = mix(0.3, 0.4, fragCoord.x / iResolution.x);
    // no dither
    fragColor = vec4(vec3(v), 1.0);
}
