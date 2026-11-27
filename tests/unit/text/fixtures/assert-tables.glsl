// Ordinary .test.glsl files have no bound textures. Use the metric test runner's
// @frame sampler to feed the real readers exact format-1 bytes.
#include <text/runs.glsl>
#include <text/subtitles.glsl>
#include <text/number.glsl>

bool run_records(kit_text_table h) {
    kit_text_line line = kit_text_read_line(sg_frame, h, 0);
    kit_text_glyph g = kit_text_read_glyph(sg_frame, h, 0, line.baseline);
    kit_text_glyph next = kit_text_read_glyph(sg_frame, h, 1, line.baseline);
    return h.format == 1 && h.kind == 0 && h.glyphs == 3 && h.lines == 2 && h.cues == 2 &&
        h.em == 64.0 && h.atlas_em == 32.0 && h.spread == 4.0 && h.pitch == 20.0 &&
        line.baseline == 20.0 && line.first == 0 && line.count == 2 && line.span == vec2(1.0, 40.0) &&
        g.origin == vec2(10.0, 18.75) && g.corner == vec2(8.0, 14.75) &&
        g.tile == ivec2(100, 1) && g.size == ivec2(4, 1) &&
        g.grapheme == 7 && g.word == 3 && g.line == 0 &&
        next.origin == vec2(24.25, 20.0) && next.size == ivec2(0);
}

bool run_lookup(kit_text_table h) {
    kit_text_line line = kit_text_read_line(sg_frame, h, 0);
    ivec2 lines = kit_text_run_lines(sg_frame, h, ivec2(0, 2), 16.0, 12.0);
    ivec2 glyphs = kit_text_run_glyphs(sg_frame, h, line, 12.0, 6.0);
    kit_text_style style = kit_text_style(vec4(1.0, 0.5, 0.0, 1.0), vec4(0.0),
        vec4(1.0), 0.0, 0.0, 1.0, vec2(0.0, 4.0));
    vec4 inside = kit_text_run(sg_frame, sg_frame, h, lines, vec2(12.0, 16.0), vec2(6.0, 12.0), 4.0, 1.0, style);
    vec4 shadow_only = kit_text_run(sg_frame, sg_frame, h, lines, vec2(12.0, 20.0), vec2(6.0, 12.0), 4.0, 1.0, style);
    kit_text_glyph g = kit_text_read_glyph(sg_frame, h, 0, line.baseline);
    kit_text_motion motion = kit_text_motion(vec2(30.0, 2.0), 2.0, 1.57079633, 0.25);
    vec4 moved = kit_text_glyph_ink(sg_frame, h, g, vec2(45.5, 24.75), 4.0, 1.0, motion, style);
    vec4 true_shadow = kit_text_run(sg_frame, sg_frame, h, lines, vec2(9.0, 20.0), vec2(6.0, 12.0), 4.0, 1.0, style);
    style.shadow = vec4(0.0);
    style.softness = 4.0;
    vec4 soft = kit_text_run(sg_frame, sg_frame, h, lines, vec2(9.0, 16.0), vec2(6.0, 12.0), 4.0, 1.0, style);
    style.fill = vec4(0.0);
    style.outline = vec4(1.0);
    style.width = 3.0;
    vec4 outline = kit_text_run(sg_frame, sg_frame, h, lines, vec2(9.0, 16.0), vec2(6.0, 12.0), 4.0, 1.0, style);
    return true_shadow == vec4(1.0) && abs(soft.a - (0.5 - 30.0 / 255.0)) < 0.0001 &&
        outline == vec4(1.0) && lines == ivec2(0, 1) && glyphs == ivec2(0, 1) &&
        inside == vec4(1.0, 0.5, 0.0, 1.0) && shadow_only == vec4(0.0) && moved == 0.25 * inside;
}

bool cue_boundaries(kit_text_table h) {
    kit_text_cue before = kit_text_find_cue(sg_frame, h, 249u);
    kit_text_cue first = kit_text_find_cue(sg_frame, h, 250u);
    kit_text_cue last = kit_text_find_cue(sg_frame, h, 499u);
    kit_text_cue next = kit_text_find_cue(sg_frame, h, 500u);
    kit_text_cue after = kit_text_find_cue(sg_frame, h, 1000u);
    kit_text_style style = kit_text_style(vec4(1.0), vec4(0.0), vec4(0.0), 0.0, 0.0, 0.0, vec2(0.0));
    vec4 plate = vec4(0.5, 0.25, 0.125, 0.5);
    vec4 visible_cue = kit_text_subtitles(sg_frame, sg_frame, h, first, vec2(0.0), vec2(10.0),
        4.0, 1.0, style, plate, vec2(1.0));
    vec4 inactive = kit_text_subtitles(sg_frame, sg_frame, h, after, vec2(0.0), vec2(10.0),
        4.0, 1.0, style, plate, vec2(1.0));
    return before.count == 0 && first.first == 0 && first.count == 1 && first.start_ms == 250u &&
        last.end_ms == 500u && next.start_ms == 500u && next.end_ms == 1000u && next.first == 1 &&
        after.count == 0 && visible_cue == plate && inactive == vec4(0.0);
}

bool set_records(kit_text_table h) {
    int zero = kit_text_set_find(sg_frame, h, 48u);
    kit_text_glyph g = kit_text_read_glyph(sg_frame, h, zero, 0.0);
    kit_text_style style = kit_text_style(vec4(1.0), vec4(0.0), vec4(0.0), 0.0, 0.0, 0.0, vec2(0.0));
    vec4 third = kit_text_number(sg_frame, sg_frame, h, 101, 0, vec2(20.0, -1.5), 4.0, 1.0, style);
    vec4 gap = kit_text_number(sg_frame, sg_frame, h, 101, 0, vec2(12.0, -1.5), 4.0, 1.0, style);
    return third == vec4(1.0) && gap == vec4(0.0) && h.kind == 1 && h.lines == 0 && zero == 1 && g.code == 48u &&
        g.origin.x == -1.0 && g.advance == 11.5 &&
        kit_text_set_find(sg_frame, h, 45u) == 0 &&
        kit_text_set_find(sg_frame, h, 0x1f600u) == 3 &&
        kit_text_set_find(sg_frame, h, 47u) == -1 && kit_text_set_find(sg_frame, h, 0u) == -1 &&
        kit_text_set_find(sg_frame, h, 0x10ffffu) == -1;
}

void mainMetric(out vec4 value, in vec2 fragCoord) {
    kit_text_table h = kit_text_read_table(sg_frame);
#ifdef SET_FIXTURE
    bool ok = h.glyphs == 4 && h.kind == 1 && set_records(h);
#else
    int region = int(fragCoord.x) % 3;
    bool ok = region == 0 ? run_records(h) : (region == 1 ? run_lookup(h) : cue_boundaries(h));
#endif
    value = ok ? vec4(0.0) : vec4(1.0, 0.0, 0.0, 1.0);
}
