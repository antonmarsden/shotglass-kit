// The pool seen through the rippled surface: the slope of the height (iChannel1,
// kit_buf_gradient over its packed channels) bends the view of the floor (iChannel0)
// and catches a sky highlight.
#include <kit/color.glsl>
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 size = vec2(textureSize(iChannel1, 0));
    vec4 w = vec4(65280.0, 255.0, 0.0, 0.0) * (2.0 / 65535.0);   // channels -> height
    vec2 g = kit_buf_gradient(iChannel1, ivec2(uv * size), false, w);
    vec3 floorCol = kit_srgb_decode(texture(iChannel0, clamp(uv - g * 0.25, 0.0, 1.0)).rgb);
    vec3 n = normalize(vec3(-g * 6.0, 1.0));
    vec3 l = normalize(vec3(-0.4, 0.6, 1.0));
    float spec = pow(max(dot(reflect(-l, n), vec3(0.0, 0.0, 1.0)), 0.0), 60.0);
    float fres = 0.15 * (1.0 - n.z) * 20.0;
    vec3 col = floorCol + vec3(0.9, 0.95, 1.0) * (spec * 0.8 + clamp(fres, 0.0, 0.3));
    fragColor = vec4(kit_srgb_encode(col), 1.0);
}
