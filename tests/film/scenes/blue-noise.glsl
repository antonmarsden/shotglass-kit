// Six-level grayscale ramp with plain rounding on the left and dithering on the right.
#include <kit/noise.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    ivec2 pixel = ivec2(floor(fragCoord)) % textureSize(iChannel0, 0);
    float texel = texelFetch(iChannel0, pixel, 0).r;
    float threshold = uv.x < 0.5 ? 0.5 : (255.0 * texel + 0.5) / 256.0;
    float tone = kit_dither(uv.y, 6, threshold);
    fragColor = vec4(vec3(tone), 1.0);
}
