// The pool seen through the rippled surface: the slope of the height (iChannel1,
// kit_buf_gradient over its packed channels) bends the view of the floor (iChannel0)
// and catches a sky highlight. Caustics: where the surface curves like a converging
// lens (positive Laplacian of the height) it focuses light onto the floor, where it
// curves the other way it spreads it, so the drops' rings cast bright and dark bands.
#include <kit/color.glsl>
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 size = vec2(textureSize(iChannel1, 0));
    vec4 w = vec4(65280.0, 255.0, 0.0, 0.0) * (2.0 / 65535.0);   // channels -> height
    ivec2 q = ivec2(uv * size);
    vec2 g = kit_buf_gradient(iChannel1, q, false, w);
    // The Laplacian of the blurred height, two texels wide: a one-texel Laplacian
    // picks out the grid-scale noise of the simulation as a moire.
    vec4 b0 = kit_buf_blur(iChannel1, q, false);
    vec4 edges = kit_buf_blur(iChannel1, q + ivec2(2, 0), false) + kit_buf_blur(iChannel1, q - ivec2(2, 0), false) +
                 kit_buf_blur(iChannel1, q + ivec2(0, 2), false) + kit_buf_blur(iChannel1, q - ivec2(0, 2), false);
    float lap = dot(edges - 4.0 * b0, w) / 4.0;
    vec3 floorCol = kit_srgb_decode(texture(iChannel0, clamp(uv - g * 0.25, 0.0, 1.0)).rgb);
    vec3 n = normalize(vec3(-g * 6.0, 1.0));
    vec3 l = normalize(vec3(-0.4, 0.6, 1.0));
    float spec = pow(max(dot(reflect(-l, n), vec3(0.0, 0.0, 1.0)), 0.0), 60.0);
    float fres = 0.15 * (1.0 - n.z) * 20.0;
    float focus = clamp(1.0 + 30.0 * lap, 0.5, 2.2);
    vec3 col = floorCol * focus + vec3(0.9, 0.95, 1.0) * (spec * 0.8 + clamp(fres, 0.0, 0.3));
    fragColor = vec4(kit_srgb_encode(col), 1.0);
}
