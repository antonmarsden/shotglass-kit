// shotglass-kit/blend: modes.glsl
//
// The blend modes' maths and the compositing step every blend pass shares. A pass
// (multiply.glsl, screen.glsl, ...) is three lines around one function from here; use
// these to build your own pass, e.g. a film-local blend that mixes two modes.
//
// Colours are the picture's display colour, 0..1 per channel (blending is done on the
// values stored in the picture, as in Photoshop and CSS, not in linear light).
// The formulas are the separable modes of W3C "Compositing and Blending Level 1".
// `cb` is the backdrop (the picture below) and `cs` the source (the layer), both
// straight (not premultiplied) colour.
// sound: picture only

// kit_blend_source(layer): the layer's straight colour from what getLayer(uv) gives.
//   layer  premultiplied rgba (colour already multiplied by alpha = coverage x opacity)
//   ->     rgb 0..1; black where the layer is nowhere covered (alpha 0)
//   e.g.   vec3 cs = kit_blend_source(getLayer(uv));
vec3 kit_blend_source(vec4 layer) {
    // 8-bit premultiplied storage can leave rgb a hair above alpha, so clamp.
    return min(layer.rgb / max(layer.a, 1e-5), 1.0);
}

// kit_blend_composite(base, layer, mixed): put a blend mode's result over the picture.
//   base   the picture below, opaque rgba (getBase(uv))
//   layer  premultiplied rgba (getLayer(uv)); its alpha is coverage x opacity
//   mixed  the mode applied to the straight colours: B(base.rgb, kit_blend_source(layer))
//   ->     opaque rgba: the base where the layer has no coverage, `mixed` where it has all
//   e.g.   return kit_blend_composite(b, l, kit_blend_multiply(b.rgb, kit_blend_source(l)));
vec4 kit_blend_composite(vec4 base, vec4 layer, vec3 mixed) {
    return vec4(mix(base.rgb, mixed, layer.a), 1.0);
}

// kit_blend_multiply(cb, cs): darkens; white leaves the picture alone, black gives black.
//   e.g. vec3 m = kit_blend_multiply(b.rgb, cs);
vec3 kit_blend_multiply(vec3 cb, vec3 cs) { return cb * cs; }

// kit_blend_screen(cb, cs): lightens; black leaves the picture alone, white gives white.
//   e.g. vec3 s = kit_blend_screen(b.rgb, cs);
vec3 kit_blend_screen(vec3 cb, vec3 cs) { return cb + cs - cb * cs; }

// kit_blend_hardlight(cb, cs): multiply where the layer is dark, screen where it is light.
//   e.g. vec3 h = kit_blend_hardlight(b.rgb, cs);
vec3 kit_blend_hardlight(vec3 cb, vec3 cs) {
    vec3 lo = cb * 2.0 * cs;
    vec3 hi = kit_blend_screen(cb, 2.0 * cs - 1.0);
    return mix(lo, hi, step(0.5, cs));
}

// kit_blend_overlay(cb, cs): multiply where the picture is dark, screen where it is
// light; hard light with the two swapped, so the picture's own contrast is kept.
//   e.g. vec3 o = kit_blend_overlay(b.rgb, cs);
vec3 kit_blend_overlay(vec3 cb, vec3 cs) { return kit_blend_hardlight(cs, cb); }

// kit_blend_add(cb, cs): linear dodge, cb + cs, clamped to white.
//   e.g. vec3 a = kit_blend_add(b.rgb, cs);
vec3 kit_blend_add(vec3 cb, vec3 cs) { return min(cb + cs, 1.0); }

// kit_blend_darken(cb, cs): the darker of the two, per channel.
//   e.g. vec3 d = kit_blend_darken(b.rgb, cs);
vec3 kit_blend_darken(vec3 cb, vec3 cs) { return min(cb, cs); }

// kit_blend_lighten(cb, cs): the lighter of the two, per channel.
//   e.g. vec3 l = kit_blend_lighten(b.rgb, cs);
vec3 kit_blend_lighten(vec3 cb, vec3 cs) { return max(cb, cs); }

// kit_blend_difference(cb, cs): |cb - cs|; identical colours give black.
//   e.g. vec3 d = kit_blend_difference(b.rgb, cs);
vec3 kit_blend_difference(vec3 cb, vec3 cs) { return abs(cb - cs); }

float kit_private_dodge(float cb, float cs) {
    if (cb <= 0.0) return 0.0;
    if (cs >= 1.0) return 1.0;
    return min(1.0, cb / (1.0 - cs));
}

float kit_private_burn(float cb, float cs) {
    if (cb >= 1.0) return 1.0;
    if (cs <= 0.0) return 0.0;
    return 1.0 - min(1.0, (1.0 - cb) / cs);
}

float kit_private_soft_light(float cb, float cs) {
    if (cs <= 0.5) return cb - (1.0 - 2.0 * cs) * cb * (1.0 - cb);
    float d = cb <= 0.25 ? ((16.0 * cb - 12.0) * cb + 4.0) * cb : sqrt(cb);
    return cb + (2.0 * cs - 1.0) * (d - cb);
}

// kit_blend_colordodge(cb, cs): brightens the picture by the layer; black in the
// layer changes nothing, white makes every lit channel white. A black picture stays black.
//   e.g. vec3 d = kit_blend_colordodge(b.rgb, cs);
vec3 kit_blend_colordodge(vec3 cb, vec3 cs) {
    return vec3(kit_private_dodge(cb.r, cs.r), kit_private_dodge(cb.g, cs.g), kit_private_dodge(cb.b, cs.b));
}

// kit_blend_colorburn(cb, cs): darkens the picture by the layer; white in the layer
// changes nothing, black makes every unlit channel black. A white picture stays white.
//   e.g. vec3 d = kit_blend_colorburn(b.rgb, cs);
vec3 kit_blend_colorburn(vec3 cb, vec3 cs) {
    return vec3(kit_private_burn(cb.r, cs.r), kit_private_burn(cb.g, cs.g), kit_private_burn(cb.b, cs.b));
}

// kit_blend_softlight(cb, cs): a gentle overlay: the layer lightens or darkens the
// picture but never reaches pure white or black from mid-greys.
//   e.g. vec3 s = kit_blend_softlight(b.rgb, cs);
vec3 kit_blend_softlight(vec3 cb, vec3 cs) {
    return vec3(kit_private_soft_light(cb.r, cs.r), kit_private_soft_light(cb.g, cs.g), kit_private_soft_light(cb.b, cs.b));
}
