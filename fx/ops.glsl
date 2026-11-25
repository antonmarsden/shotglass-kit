// shotglass-kit/fx: ops.glsl
//
// The maths behind the fx passes (grade.glsl, grain.glsl, ...): each pass is a few lines
// of mainImage around one function from here, so they can be unit tested and reused in
// your own layer shaders. Colours are display colour, 0..1 (what is on screen).
//
// A pass's `params` are macros, which rewrite every identifier of their name in the
// pass and in what it includes. So the parameters here are named differently from the
// params (lo and gn, not lift and gain), and your own code that
// includes this file next to a pass should do the same.
// sound: picture only

// kit_fx_grade(col, stops, contrast, saturation, lo, gn): the grade, as a function.
//   col         display colour, 0..1
//   stops       exposure in stops (powers of two)
//   contrast    1 = none; stretches around 0.5
//   saturation  1 = none, 0 = grey
//   lo, gn      lift (0 = none) and gain (1 = none), per channel
//   ->          display colour, 0..1
//   e.g.        col = kit_fx_grade(col, 0.5, 1.1, 1.2, vec3(0.0), vec3(1.0));
vec3 kit_fx_grade(vec3 col, float stops, float contrast, float saturation, vec3 lo, vec3 gn) {
    vec3 c = col * exp2(stops);
    c = c * gn + lo * (1.0 - c);
    c = (c - 0.5) * contrast + 0.5;
    c = mix(vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))), c, saturation);
    return clamp(c, 0.0, 1.0);
}

// core's integer hash (lowbias32 over 3 inputs), copied so the grain is the same as
// core's kit_grain: a film names its libraries itself, so fx can't #include <kit/...>.
uint kit__fx_mix(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352dU;
    x ^= x >> 15;
    x *= 0x846ca68bU;
    x ^= x >> 16;
    return x;
}
float kit__fx_hash(uvec3 v) {
    uint h = kit__fx_mix(v.x ^ kit__fx_mix(v.y ^ kit__fx_mix(v.z + 0x9e3779b9U) + 0x7f4a7c15U));
    return float(h >> 8) * (1.0 / 16777216.0);
}

// kit_fx_grain(col, fragCoord, frame, strength, tint): film grain.
//   col        display colour
//   fragCoord  pixel position (as passed to mainImage)
//   frame      frame number (iFrame); the grain changes with it
//   strength   0..0.2 typically; full range of the noise, in colour units
//   tint       0 = the same grain on every channel, 1 = independent per channel
//   ->         col plus noise in -strength/2..strength/2, clamped to 0..1; with
//              tint 0 it is core's kit_grain(col, fragCoord, frame, strength)
//   e.g.       col = kit_fx_grain(col, fragCoord, iFrame, 0.06, 0.0);
vec3 kit_fx_grain(vec3 col, vec2 fragCoord, int frame, float strength, float tint) {
    uvec3 cell = uvec3(ivec3(ivec2(floor(fragCoord)), frame));
    vec3 g = vec3(kit__fx_hash(cell),
                  kit__fx_hash(cell ^ uvec3(0U, 0U, 0x55555555U)),
                  kit__fx_hash(cell ^ uvec3(0U, 0U, 0x2aaaaaaaU)));
    g = mix(vec3(g.x), g, tint) - 0.5;
    return clamp(col + g * strength, 0.0, 1.0);
}

// kit_fx_vignette(uv, strength, soft): how much of the vignette colour covers a point.
//   uv        0..1 across the frame (fragCoord / iResolution.xy)
//   strength  0..1, coverage in the corners
//   soft      0..1, how far in it starts (1 = from the centre); clamped to 0.001..1
//   ->        0 in the middle, `strength` in the corners
//   e.g.      float a = kit_fx_vignette(uv, 0.4, 0.6);
float kit_fx_vignette(vec2 uv, float strength, float soft) {
    float d = length(uv - 0.5) * 1.41421356;   // 0 centre, 1 corner
    return strength * smoothstep(1.0 - clamp(soft, 0.001, 1.0), 1.0, d);
}

// kit_fx_letterbox(uv, frame_aspect, target, px): how much of the frame point is bar.
//   uv            0..1 across the frame
//   frame_aspect  the frame's width / height (iResolution.x / iResolution.y)
//   target        the picture area's width / height; > 0
//   px            one pixel, in uv units of the frame's height (1.0 / iResolution.y)
//   ->            0 inside the picture area, 1 in the bars, blended over one pixel
//   e.g.          float bar = kit_fx_letterbox(uv, iResolution.x / iResolution.y, 2.39, 1.0 / iResolution.y);
float kit_fx_letterbox(vec2 uv, float frame_aspect, float target, float px) {
    // Distance in frame heights from the edge of the picture area, positive inside it.
    vec2 half_size = 0.5 * vec2(min(target, frame_aspect), min(1.0, frame_aspect / target));
    vec2 p = abs((uv - 0.5) * vec2(frame_aspect, 1.0));
    vec2 inside = half_size - p;
    return 1.0 - clamp(min(inside.x, inside.y) / px + 0.5, 0.0, 1.0);
}

// kit_fx_place(uv, frame_aspect, pic_aspect, pos, height, pin, px): where a point falls
// on the placed picture.
//   uv            0..1 across the frame
//   frame_aspect  the frame's width / height
//   pic_aspect    the picture's width / height; <= 0 (nothing bound) gives no coverage
//   pos           0..1 of the frame: where `pin` goes
//   height        the picture's height in frame heights
//   pin           0..1 of the picture: its point put at `pos`
//   px            one pixel in frame heights (1.0 / iResolution.y)
//   ->            xy: 0..1 across the picture (clamped); z: 0..1 coverage, 0 outside it
//   e.g.          vec3 q = kit_fx_place(uv, iResolution.x / iResolution.y, 1.5, vec2(0.9), 0.1, vec2(1.0), 1.0 / iResolution.y);
vec3 kit_fx_place(vec2 uv, float frame_aspect, float pic_aspect, vec2 pos, float height, vec2 pin, float px) {
    vec2 size = vec2(max(pic_aspect, 0.0) * height, height);
    vec2 corner = pos * vec2(frame_aspect, 1.0) - pin * size;       // bottom left, frame heights
    vec2 local = (uv * vec2(frame_aspect, 1.0) - corner) / max(size, vec2(1e-6));
    vec2 inside = min(local, 1.0 - local) * size;                   // distance in from each edge
    float cover = clamp(min(inside.x, inside.y) / px + 0.5, 0.0, 1.0);
    return vec3(clamp(local, 0.0, 1.0), pic_aspect > 0.0 ? cover : 0.0);
}

// kit_fx_bright(col, from, width): the colour scaled by how far its luma is past a threshold.
//   col    display colour, 0..1
//   from   luma where it starts to pass, 0..1
//   width  luma it takes to pass fully; <= 0 is a hard cut at `from`
//   ->     col x 0..1: 0 at or below `from`, all of col at `from + width` or above
//   e.g.   vec3 glow = kit_fx_bright(col, 0.6, 0.25);
vec3 kit_fx_bright(vec3 col, float from, float width) {
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    return col * (width > 0.0 ? smoothstep(from, from + width, luma) : step(from, luma));
}

// kit_fx_chroma_key(plate, key, cutoff, width, strength): key a straight-alpha plate.
//   plate     straight display RGBA, 0..1
//   key       screen sample in display RGB, 0..1
//   cutoff    distance in RGB chroma units; <= cutoff is clear, clamped to 0..2
//   width     distance from cutoff to full coverage, clamped to 1e-6..2 if positive;
//             <= 0 gives a hard cut
//   strength  spill removal, clamped to 0..1; 0 keeps RGB, 1 removes the positive
//             projection along the key's chroma; removal fades to zero below
//             1e-6 key chroma magnitude
//   ->        straight display RGBA, 0..1; alpha is plate.a times the smooth matte
//             computed from the original RGB, independently of spill removal
//   e.g.      fragColor = kit_fx_chroma_key(plate, vec3(0.0, 1.0, 0.0), 0.12, 0.30, 1.0);
vec4 kit_fx_chroma_key(vec4 plate, vec3 key, float cutoff, float width, float strength) {
    // Project onto the plane perpendicular to neutral RGB. Starting with
    // channel differences makes true greys map to exactly zero.
    vec3 chroma = plate.rgb - plate.g;
    vec3 screen = key - key.g;
    chroma -= (chroma.r + chroma.b) / 3.0;
    screen -= (screen.r + screen.b) / 3.0;
    float distance_from_cutoff = length(chroma - screen) - clamp(cutoff, 0.0, 2.0);
    float matte = width > 0.0
        ? smoothstep(0.0, clamp(width, 1e-6, 2.0), distance_from_cutoff)
        : (distance_from_cutoff > 0.0 ? 1.0 : 0.0);

    float spill = max(dot(chroma, screen), 0.0) / max(dot(screen, screen), 1e-12);
    vec3 rgb = clamp(plate.rgb - clamp(strength, 0.0, 1.0) * spill * screen, 0.0, 1.0);
    return vec4(rgb, plate.a * matte);
}
