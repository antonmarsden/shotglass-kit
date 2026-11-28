// The feedback tunnel (iChannel0), opaque, over everything below.
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = vec4(kit_buf_sample(iChannel0, uv, false).rgb, 1.0);
}
