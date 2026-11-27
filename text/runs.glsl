// shotglass-kit/text: runs.glsl
// sound: picture only
// Format 1 glyph tables. Positions and distances are layout texels, x right and y
// down. Atlas tiles and table rows start at the top.
// Search cost: logarithmic in line/glyph counts plus the number of nearby records.

struct kit_text_table {
    int format, kind;
    int glyphs, lines, cues;
    int first_line, first_glyph, first_cue;
    int line_stride, glyph_stride, cue_stride;
    float em, atlas_em, spread, pitch;
};

struct kit_text_line {
    float baseline;
    vec2 span;
    int first, count;
};

struct kit_text_glyph {
    vec2 origin, corner;
    ivec2 tile, size;
    int grapheme, word, line;
    uint code;
    float advance;
};

struct kit_text_cue {
    uint start_ms, end_ms;
    int first, count;
};

struct kit_text_motion {
    vec2 offset;
    float scale, angle, opacity;
};

struct kit_text_style {
    vec4 fill, outline, shadow; // straight display RGBA
    float width, softness, shadow_softness;
    vec2 shadow_offset;
};

uvec4 kit_private_text_bytes(sampler2D table, int at) {
    return uvec4(texelFetch(table, ivec2(at % 1024, at / 1024), 0) * 255.0 + 0.5);
}

uint kit_private_text_u32(sampler2D table, int at) {
    uvec4 b = kit_private_text_bytes(table, at);
    return (b.r << 24) | (b.g << 16) | (b.b << 8) | b.a;
}

uvec2 kit_private_text_pair(sampler2D table, int at) {
    uvec4 b = kit_private_text_bytes(table, at);
    return (b.rb << 8) | b.ga;
}

float kit_private_text_signed(uint value) {
    return float(int(value) - (value >= 32768u ? 65536 : 0)) / 16.0;
}

// Open a glyph table. An unbound sampler, or an unsupported header, yields zero counts.
kit_text_table kit_text_read_table(sampler2D table) {
    ivec2 size = textureSize(table, 0);
    if (size.x != 1024 || size.y == 0) {
        return kit_text_table(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, 0.0);
    }
    uvec2 tag = kit_private_text_pair(table, 0);
    uvec2 em = kit_private_text_pair(table, 5);
    uvec2 spread_pitch = kit_private_text_pair(table, 6);
    uvec2 stride = kit_private_text_pair(table, 7);
    uint cue_stride = kit_private_text_pair(table, 10).x;
    kit_text_table h = kit_text_table(int(tag.x), int(tag.y), 0, 0, 0, 0, 0, 0,
        int(stride.x), int(stride.y), int(cue_stride),
        float(em.x) / 16.0, float(em.y) / 16.0,
        float(spread_pitch.x) / 256.0, float(spread_pitch.y) / 16.0);
    if (tag.x != 1u || tag.y > 1u || stride != uvec2(4, 6) || cue_stride != 4u ||
        em.x == 0u || em.y == 0u) return h;
    h.glyphs = int(kit_private_text_u32(table, 1));
    h.lines = int(kit_private_text_u32(table, 2));
    h.first_line = int(kit_private_text_u32(table, 3));
    h.first_glyph = int(kit_private_text_u32(table, 4));
    h.cues = int(kit_private_text_u32(table, 8));
    h.first_cue = int(kit_private_text_u32(table, 9));
    return h;
}

// Read an in-range visual line or glyph index. Set glyphs take baseline 0.
kit_text_line kit_text_read_line(sampler2D table, kit_text_table h, int index) {
    int at = h.first_line + index * h.line_stride;
    uvec2 range = kit_private_text_pair(table, at + 1);
    return kit_text_line(float(kit_private_text_u32(table, at)) / 256.0,
        vec2(kit_private_text_pair(table, at + 2)) / 16.0, int(range.x), int(range.y));
}

kit_text_glyph kit_text_read_glyph(sampler2D table, kit_text_table h, int index, float baseline) {
    int at = h.first_glyph + index * h.glyph_stride;
    uvec2 pen = kit_private_text_pair(table, at);
    uvec2 bearing = kit_private_text_pair(table, at + 3);
    uvec2 tail = kit_private_text_pair(table, at + 5);
    vec2 origin = vec2(float(pen.x) / 16.0 + kit_private_text_signed(tail.y),
                       baseline + kit_private_text_signed(pen.y));
    vec2 corner = origin + vec2(kit_private_text_signed(bearing.x),
                               -kit_private_text_signed(bearing.y)) * (h.em / h.atlas_em);
    kit_text_glyph g = kit_text_glyph(origin, corner,
        ivec2(kit_private_text_pair(table, at + 1)), ivec2(kit_private_text_pair(table, at + 2)),
        0, 0, 0, 0u, 0.0);
    if (h.kind == 1) {
        g.code = kit_private_text_u32(table, at + 4);
        g.advance = float(tail.x) / 16.0;
    } else {
        uvec2 indices = kit_private_text_pair(table, at + 4);
        g.grapheme = int(indices.x);
        g.word = int(indices.y);
        g.line = int(tail.x);
    }
    return g;
}

kit_text_cue kit_private_text_read_cue(sampler2D table, kit_text_table h, int index) {
    int at = h.first_cue + index * h.cue_stride;
    uvec2 lines = kit_private_text_pair(table, at + 2);
    return kit_text_cue(kit_private_text_u32(table, at), kit_private_text_u32(table, at + 1),
                        int(lines.x), int(lines.y));
}

float kit_private_text_pen(sampler2D table, kit_text_table h, int index) {
    return float(kit_private_text_pair(table, h.first_glyph + index * h.glyph_stride).x) / 16.0;
}

int kit_private_text_bound(sampler2D table, kit_text_table h, ivec2 range,
                          float value, bool by_line, bool upper) {
    int lo = range.x;
    int hi = range.y;
    while (lo < hi) {
        int mid = lo + (hi - lo) / 2;
        float key = by_line ? float(kit_private_text_u32(table, h.first_line + mid * h.line_stride)) / 256.0
                            : kit_private_text_pen(table, h, mid);
        if (key < value || (upper && key == value)) lo = mid + 1;
        else hi = mid;
    }
    return lo;
}

// Half-open candidate ranges, including equal keys and overlapping tiles. `reach`
// bounds the distance from the baseline or pen to any contributing pixel, including
// transformed tiles and shadows. It must be nonnegative. `lines` is [first, end).
ivec2 kit_text_run_lines(sampler2D table, kit_text_table h, ivec2 lines, float y, float reach) {
    return ivec2(kit_private_text_bound(table, h, lines, y - reach, true, false),
                 kit_private_text_bound(table, h, lines, y + reach, true, true));
}

ivec2 kit_text_run_glyphs(sampler2D table, kit_text_table h, kit_text_line line, float x, float reach) {
    ivec2 range = ivec2(line.first, line.first + line.count);
    return ivec2(kit_private_text_bound(table, h, range, x - reach, false, false),
                 kit_private_text_bound(table, h, range, x + reach, false, true));
}

bool kit_private_text_in_tile(vec2 q, vec2 size) {
    return all(greaterThanEqual(q, vec2(0.0))) && all(lessThan(q, size));
}

vec2 kit_private_text_distances(sampler2D atlas, kit_text_glyph g, vec2 q, float reach) {
    vec2 sample_at = q - 0.5;
    vec2 cell = floor(sample_at);
    vec2 f = sample_at - cell;
    ivec2 last = g.size - 1;
    ivec2 a = g.tile + clamp(ivec2(cell), ivec2(0), last);
    ivec2 b = g.tile + clamp(ivec2(cell) + 1, ivec2(0), last);
    vec4 d = mix(mix(texelFetch(atlas, a, 0), texelFetch(atlas, ivec2(b.x, a.y), 0), f.x),
                 mix(texelFetch(atlas, ivec2(a.x, b.y), 0), texelFetch(atlas, b, 0), f.x), f.y);
    float median_rgb = max(min(d.r, d.g), min(max(d.r, d.g), d.b));
    return (vec2(median_rgb, d.a) - 127.5 / 255.0) * (2.0 * reach);
}

vec2 kit_private_text_tile_point(vec2 p, kit_text_glyph g, kit_text_motion motion, float k) {
    vec2 q = p - g.origin - motion.offset;
    float c = cos(motion.angle);
    float s = sin(motion.angle);
    q = mat2(c, -s, s, c) * q / motion.scale;
    return (q + g.origin - g.corner) / k;
}

vec4 kit_private_text_over(vec4 front, vec4 back) {
    return front + (1.0 - front.a) * back;
}

vec4 kit_private_text_colour(vec4 colour, float coverage) {
    float alpha = colour.a * coverage;
    return vec4(colour.rgb * alpha, alpha);
}

vec4 kit_private_text_straight(vec4 colour) {
    return vec4(colour.rgb / max(colour.a, 1e-20), colour.a);
}

// Draw one glyph with a caller-supplied transform about its origin. Angle in radians
// is clockwise, opacity clamps to 0..1, scale <= 0 hides the glyph. Style lengths and
// pixel (layout texels per screen pixel) are in the output layout coordinate space.
// Use iChannelMeta[atlas].y for spread in atlas texels. Output is premultiplied RGBA.
vec4 kit_text_glyph_ink(sampler2D atlas, kit_text_table h, kit_text_glyph g, vec2 p,
                       float spread, float pixel, kit_text_motion motion, kit_text_style style) {
    if (any(lessThanEqual(g.size, ivec2(0))) || motion.scale <= 0.0 ||
        motion.opacity <= 0.0 || spread <= 0.0) return vec4(0.0);
    float k = h.em / h.atlas_em;
    float reach = spread * k * motion.scale;
    vec4 result = vec4(0.0);
    vec2 q = kit_private_text_tile_point(p, g, motion, k);
    vec2 size = vec2(g.size);
    if (style.shadow.a > 0.0) {
        vec2 shadow = kit_private_text_tile_point(p - style.shadow_offset, g, motion, k);
        if (kit_private_text_in_tile(shadow, size)) {
            float d = kit_private_text_distances(atlas, g, shadow, reach).y;
            float edge = max(max(pixel, style.shadow_softness), 1e-6);
            result = kit_private_text_colour(style.shadow, smoothstep(-0.5, 0.5, d / edge));
        }
    }
    if (kit_private_text_in_tile(q, size)) {
        float d = kit_private_text_distances(atlas, g, q, reach).x;
        float edge = max(max(pixel, style.softness), 1e-6);
        if (style.width > 0.0 && style.outline.a > 0.0) {
            float width = min(style.width, max(0.0, reach - 0.5 * edge));
            vec4 outline = kit_private_text_colour(style.outline, clamp((d + width) / edge + 0.5, 0.0, 1.0));
            result = kit_private_text_over(outline, result);
        }
        vec4 fill = kit_private_text_colour(style.fill, clamp(d / edge + 0.5, 0.0, 1.0));
        result = kit_private_text_over(fill, result);
    }
    return result * min(motion.opacity, 1.0);
}

// Draw a static range of visual lines. Reach is the maximum x/y distance from
// pen/baseline to a contributing pixel. Returns premultiplied display RGBA.
vec4 kit_text_run(sampler2D atlas, sampler2D table, kit_text_table h, ivec2 lines, vec2 p,
                  vec2 reach, float spread, float pixel, kit_text_style style) {
    vec4 result = vec4(0.0);
    ivec2 rows = kit_text_run_lines(table, h, lines, p.y, reach.y);
    for (int row = rows.x; row < rows.y; ++row) {
        kit_text_line line = kit_text_read_line(table, h, row);
        ivec2 glyphs = kit_text_run_glyphs(table, h, line, p.x, reach.x);
        for (int i = glyphs.x; i < glyphs.y; ++i) {
            kit_text_glyph g = kit_text_read_glyph(table, h, i, line.baseline);
            vec4 ink = kit_text_glyph_ink(atlas, h, g, p, spread, pixel,
                kit_text_motion(vec2(0.0), 1.0, 0.0, 1.0), style);
            result = kit_private_text_over(ink, result);
        }
    }
    return result;
}
