// shotglass-kit/text: block.glsl
//
// Drawing a shotglass text block (a [texts] entry bound to an iChannel, shotglass
// 0.1.3): where it lands in the frame, and its ink, outline, glow and shadow, crisp at
// any size. The engine rasterises the words once into an RGBA8 texture (R and A:
// coverage; G: signed distance, 0.5 on the outline, +0.5 per padding texel inside) and
// gives its metrics in iChannelMeta[n] = (em, first baseline from the top, line pitch,
// padding), in texels. These functions take that texture, iChannelResolution[n] and
// iChannelMeta[n] as parameters and read no uniforms themselves.
//
// Sizes are in ems (the block's font size), so an outline 0.05 em wide looks the same
// on a 48 px caption and a 160 px title. Everything reaches at most kit_text_reach(meta)
// ems outside the letters (the block's sdf_spread, 8 texels by default, over its size):
// raise sdf_spread in movie.toml for wider outlines, glows and soft shadows.
//
// Assumes the block's default sampling (filter "linear", wrap any, vflip = true); the
// vflip mapping is handled here, so code never flips v itself. The functions that read
// the texture use derivatives (fwidth): call them from mainImage outside any branch
// that differs between neighbouring pixels.
// sound: picture only

// kit_text_box: where a pixel falls in a placed block. Make one with kit_text_place,
// kit_text_place_anchor or kit_text_place_baseline; pass it to the drawing functions.
//   uv     where to sample the block's texture (vflip handled)
//   texel  the same point in texels, from the block's top-left corner, y down
//   local  0..1 across the block's text (its padding excluded), x right, y up; outside
//          the text it runs past 0..1. For gradients and wipes across the words
//   p      in ems from the start of the first baseline, x right, y up (line n's
//          baseline is at y = -n * meta.z / meta.x)
//   scale  frame pixels per texel (1 = drawn at the size it was rasterised)
//   size   the block's size in texels (iChannelResolution[n].xy)
//   meta   iChannelMeta[n]
struct kit_text_box {
    vec2 uv;
    vec2 texel;
    vec2 local;
    vec2 p;
    float scale;
    vec2 size;
    vec4 meta;
};

// kit_private_text_box(size, meta, texel, scale): fill in a box from a texel position.
kit_text_box kit_private_text_box(vec2 size, vec4 meta, vec2 texel, float scale) {
    float em = max(meta.x, 1e-6);
    float pad = meta.w;
    vec2 inner = max(size - 2.0 * pad, vec2(1e-6));
    kit_text_box b;
    b.uv = vec2(texel.x / size.x, 1.0 - texel.y / size.y);
    b.texel = texel;
    b.local = vec2(texel.x - pad, size.y - pad - texel.y) / inner;
    b.p = vec2(texel.x - pad, meta.y - texel.y) / em;
    b.scale = scale;
    b.size = size;
    b.meta = meta;
    return b;
}

// kit_text_place_anchor(res, meta, fragCoord, frame, pos, em, anchor): place a block so
// the point `anchor` of its text sits at `pos` in the frame, its em `em` frame heights.
// Blocks placed with the same `em` show their letters the same size, whatever size each
// was rasterised at.
//   res        iChannelResolution[n] (only .xy is used)
//   meta       iChannelMeta[n]
//   fragCoord  as passed to mainImage
//   frame      iResolution.xy
//   pos        0..1 across the frame (uv), where the anchor lands
//   em         the font size, in frame heights (0.1 = ten lines of solid type fill the frame)
//   anchor     0..1 across the block's text, padding excluded: (0, 0) bottom left,
//              (0.5, 0.5) centre, (1, 1) top right
//   ->         a kit_text_box for this pixel
//   e.g. kit_text_box b = kit_text_place_anchor(iChannelResolution[0], iChannelMeta[0],
//            fragCoord, iResolution.xy, vec2(0.05, 0.05), 0.06, vec2(0.0));   // bottom left
kit_text_box kit_text_place_anchor(vec3 res, vec4 meta, vec2 fragCoord, vec2 frame, vec2 pos, float em, vec2 anchor) {
    vec2 size = max(res.xy, vec2(1.0));
    float scale = max(em * frame.y, 1e-6) / max(meta.x, 1e-6);
    float pad = meta.w;
    vec2 at = vec2(pad + anchor.x * (size.x - 2.0 * pad), pad + (1.0 - anchor.y) * (size.y - 2.0 * pad));
    vec2 d = (fragCoord - pos * frame) / scale;
    return kit_private_text_box(size, meta, at + vec2(d.x, -d.y), scale);
}

// kit_text_place(res, meta, fragCoord, frame, pos, em): place a block with its text
// centred on `pos`. Same as kit_text_place_anchor with anchor (0.5, 0.5).
//   e.g. kit_text_box b = kit_text_place(iChannelResolution[0], iChannelMeta[0],
//            fragCoord, iResolution.xy, vec2(0.5, 0.55), 0.12);
kit_text_box kit_text_place(vec3 res, vec4 meta, vec2 fragCoord, vec2 frame, vec2 pos, float em) {
    return kit_text_place_anchor(res, meta, fragCoord, frame, pos, em, vec2(0.5));
}

// kit_text_place_baseline(res, meta, fragCoord, frame, pos, em, align): place a block by
// its first baseline, so blocks of different sizes and fonts sit on a common line (a
// name and a role in a lower third, a title and its subtitle).
//   pos    0..1 across the frame: pos.y is where the first baseline goes, pos.x where
//          the point `align` of the text's width goes
//   align  0 = text starts at pos.x, 0.5 = centred on it, 1 = ends at it
//   other parameters as for kit_text_place_anchor
//   e.g. kit_text_box name = kit_text_place_baseline(iChannelResolution[0], iChannelMeta[0],
//            fragCoord, iResolution.xy, vec2(0.08, 0.2), 0.07, 0.0);
kit_text_box kit_text_place_baseline(vec3 res, vec4 meta, vec2 fragCoord, vec2 frame, vec2 pos, float em, float align) {
    vec2 size = max(res.xy, vec2(1.0));
    float scale = max(em * frame.y, 1e-6) / max(meta.x, 1e-6);
    float pad = meta.w;
    vec2 at = vec2(pad + align * (size.x - 2.0 * pad), meta.y);
    vec2 d = (fragCoord - pos * frame) / scale;
    return kit_private_text_box(size, meta, at + vec2(d.x, -d.y), scale);
}

// kit_text_offset(b, offset): the same box looking at another point of the block, as if
// the block were moved by -offset: for shadows, echoes and split colour channels.
//   offset  in ems, x right, y up (vec2(0.04, -0.04): the block appears moved down right)
//   e.g. float back = kit_text_edge(iChannel0, kit_text_offset(b, vec2(0.03, -0.03)), 0.0);
kit_text_box kit_text_offset(kit_text_box b, vec2 offset) {
    vec2 t = b.texel - vec2(offset.x, -offset.y) * b.meta.x;
    return kit_private_text_box(b.size, b.meta, t, b.scale);
}

// kit_text_reach(meta): how far outside the letters the distance field reaches, in ems
// (the block's sdf_spread over its size: 8 / 64 = 0.125 em by default). Outlines,
// glows, shadow softness and edge offsets are flat beyond it.
//   e.g. float w = min(0.2, kit_text_reach(iChannelMeta[0]));
float kit_text_reach(vec4 meta) {
    return meta.w / max(meta.x, 1e-6);
}

// kit_text_distance_em(g, meta): a distance-field value (the texture's green) as a
// signed distance in ems: 0 on the outline, positive inside the letters, negative
// outside, within +-kit_text_reach(meta).
//   g   0..1, texture(...).g
//   e.g. float d = kit_text_distance_em(texture(iChannel0, b.uv).g, b.meta);
float kit_text_distance_em(float g, vec4 meta) {
    return (g - 0.5) * 2.0 * meta.w / max(meta.x, 1e-6);
}

// kit_text_ink(d, w): antialiased inside-ness of a signed distance: 0 outside, 1 inside,
// a linear ramp w wide centred on the edge.
//   d   signed distance, positive inside (any unit)
//   w   the ramp's width in d's units, about one pixel's (fwidth(d)); 0 gives a hard edge
//   ->  0..1
//   e.g. float ink = kit_text_ink(d + 0.02, fwidth(d));
float kit_text_ink(float d, float w) {
    return clamp(d / max(w, 1e-6) + 0.5, 0.0, 1.0);
}

// kit_text_distance(tex, b): the signed distance from this pixel to the letters, in
// ems (positive inside), from the distance field. Outside the block it is
// -kit_text_reach(b.meta), whatever the texture's wrap.
//   tex  the block's iChannel
//   cost: 1 texture read
//   e.g. float d = kit_text_distance(iChannel0, b);
float kit_text_distance(sampler2D tex, kit_text_box b) {
    float g = texture(tex, b.uv).g;
    bool inside = all(greaterThanEqual(b.uv, vec2(0.0))) && all(lessThanEqual(b.uv, vec2(1.0)));
    return kit_text_distance_em(inside ? g : 0.0, b.meta);
}

// kit_text_edge(tex, b, offset): the letters' ink, from the distance field: one-pixel
// antialiasing at any scale, crisp when magnified far beyond the rasterised size.
//   tex     the block's iChannel
//   offset  in ems: > 0 grows the letters (bolder), < 0 thins them; within
//           +-kit_text_reach(b.meta)
//   ->      0..1
//   cost: 1 texture read
//   e.g. col = mix(col, vec3(1.0), kit_text_edge(iChannel0, b, 0.0));
float kit_text_edge(sampler2D tex, kit_text_box b, float offset) {
    float d = kit_text_distance(tex, b);
    return kit_text_ink(d + offset, fwidth(d));
}

// kit_text_coverage(tex, b): the letters' ink, from the rasterised coverage (R) when
// drawn at about its size or smaller, blending to kit_text_edge when magnified (from
// 1.5x to 3x), where coverage alone turns blurry.
//   ->  0..1
//   cost: 2 texture reads
//   e.g. float cov = kit_text_coverage(iChannel0, b);
float kit_text_coverage(sampler2D tex, kit_text_box b) {
    bool inside = all(greaterThanEqual(b.uv, vec2(0.0))) && all(lessThanEqual(b.uv, vec2(1.0)));
    float cov = inside ? texture(tex, b.uv).r : 0.0;
    float edge = kit_text_edge(tex, b, 0.0);
    return mix(cov, edge, smoothstep(1.5, 3.0, b.scale));
}

// kit_text_outline(tex, b, width): a band around the outside of the letters (not
// under them), antialiased on both sides.
//   width  in ems, 0..kit_text_reach(b.meta)
//   ->     0..1; draw it under or over kit_text_edge
//   cost: 1 texture read
//   e.g. col = mix(col, vec3(0.0), kit_text_outline(iChannel0, b, 0.05));
float kit_text_outline(sampler2D tex, kit_text_box b, float width) {
    float d = kit_text_distance(tex, b);
    float w = fwidth(d);
    return kit_text_ink(d + max(width, 0.0), w) - kit_text_ink(d, w);
}

// kit_text_glow(tex, b, radius): a soft halo, 1 on and inside the letters, falling
// smoothly to 0 at `radius` ems outside them.
//   radius  in ems, 0..kit_text_reach(b.meta)
//   ->      0..1; add it under the ink: col += glowColour * glow * (1.0 - ink)
//   cost: 1 texture read
//   e.g. col += vec3(0.3, 0.5, 1.0) * kit_text_glow(iChannel0, b, 0.1);
float kit_text_glow(sampler2D tex, kit_text_box b, float radius) {
    float d = kit_text_distance(tex, b);
    float g = 1.0 - smoothstep(0.0, max(radius, 1e-6), -d);
    return g * g;
}

// kit_text_shadow(tex, b, offset, softness): the letters' shape, moved by `offset` and
// blurred: a drop shadow. Draw it first, then the ink over it.
//   offset    in ems, x right, y up (vec2(0.05, -0.05): down and to the right)
//   softness  in ems: the width of the blurred edge, 0 = as sharp as the ink;
//             up to 2 * kit_text_reach(b.meta)
//   ->        0..1
//   cost: 1 texture read
//   e.g. col = mix(col, vec3(0.0), 0.6 * kit_text_shadow(iChannel0, b, vec2(0.04, -0.04), 0.1));
float kit_text_shadow(sampler2D tex, kit_text_box b, vec2 offset, float softness) {
    float d = kit_text_distance(tex, kit_text_offset(b, offset));
    return kit_text_ink(d, max(fwidth(d), softness));
}
