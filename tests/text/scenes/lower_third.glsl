// A lower third: a name (Inter Bold, iChannel0) and a role (Atkinson Hyperlegible,
// iChannel1) on one baseline though they were rasterised at different sizes, on a plate
// that slides in; a credit (Atkinson Hyperlegible Bold, iChannel2) anchored to the top
// right corner; and the name magnified, thinned and thickened with the edge offset.
// (uIn is declared from movie.toml.)
#include <text/block.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;
    vec3 col = mix(vec3(0.36, 0.48, 0.55), vec3(0.62, 0.70, 0.66), uv.y);

    // The plate, sliding in from the left.
    float slide = mix(-0.6, 0.0, uIn);
    float plate = step(uv.x, 0.52 + slide) * step(0.12, uv.y) * step(uv.y, 0.27);
    col = mix(col, vec3(0.08, 0.09, 0.12), 0.85 * plate);

    // Name and role share the baseline at 0.17 of the frame height; the role starts
    // where the plate's text column does, offset to the right of the name.
    float base = 0.17;
    kit_text_box n = kit_text_place_baseline(iChannelResolution[0], iChannelMeta[0], fragCoord, res, vec2(0.05 + slide, base), 0.07, 0.0);
    kit_text_box r = kit_text_place_baseline(iChannelResolution[1], iChannelMeta[1], fragCoord, res, vec2(0.49 + slide, base), 0.04, 1.0);
    col = mix(col, vec3(1.0), kit_text_edge(iChannel0, n, 0.0));
    col = mix(col, vec3(1.0, 0.78, 0.35), kit_text_coverage(iChannel1, r));

    // The credit's top right corner 4% in from the frame's.
    kit_text_box c = kit_text_place_anchor(iChannelResolution[2], iChannelMeta[2], fragCoord, res, vec2(1.0 - 0.04 * res.y / res.x, 0.96), 0.035, vec2(1.0));
    col = mix(col, vec3(0.1, 0.12, 0.16), kit_text_edge(iChannel2, c, 0.0));

    // The name three times, 0.12 frame heights per em (about 2x its raster at 1080p),
    // the edge offset -0.03, 0 and +0.03 em; each with an echo moved by
    // kit_text_offset and a rule just under its baseline (from p, in ems, and local).
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        kit_text_box z = kit_text_place_baseline(iChannelResolution[0], iChannelMeta[0], fragCoord, res, vec2(0.5, 0.8 - 0.17 * fi), 0.12, 0.5);
        float off = 0.03 * (fi - 1.0);
        float echo = kit_text_edge(iChannel0, kit_text_offset(z, vec2(0.04, -0.03)), off);
        float ink = kit_text_edge(iChannel0, z, off);
        float rule = step(-0.1, z.p.y) * step(z.p.y, -0.07) * step(0.0, z.local.x) * step(z.local.x, 1.0);
        col = mix(col, vec3(0.95, 0.5, 0.3), rule);
        col = mix(col, vec3(0.2, 0.25, 0.35), 0.5 * echo);
        col = mix(col, vec3(0.98, 0.96, 0.9), ink);
    }
    fragColor = vec4(col, 1.0);
}
