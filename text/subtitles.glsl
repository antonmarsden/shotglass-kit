// shotglass-kit/text: subtitles.glsl
// sound: picture only
// Cue lookup uses film milliseconds and half-open intervals. Layout is centered
// horizontally on the cue's union of line spans, with a fixed final baseline.

#include "runs.glsl"

// The cue at ms, or an empty cue before, between or after cues.
kit_text_cue kit_text_find_cue(sampler2D table, kit_text_table h, uint ms) {
    int lo = 0;
    int hi = h.cues;
    while (lo < hi) {
        int mid = lo + (hi - lo) / 2;
        kit_text_cue cue = kit_private_text_read_cue(table, h, mid);
        if (ms < cue.start_ms) hi = mid;
        else if (ms >= cue.end_ms) lo = mid + 1;
        else return cue;
    }
    return kit_text_cue(0u, 0u, 0, 0);
}

// Draw the active cue. p is layout texels relative to center x and the last
// baseline, y down. The plate is straight display RGBA, its padding in layout
// texels; the return is straight display RGBA for a Shotglass layer scene.
// Reach, spread and pixel follow kit_text_run.
vec4 kit_text_subtitles(sampler2D atlas, sampler2D table, kit_text_table h, kit_text_cue cue, vec2 p,
                        vec2 reach, float spread, float pixel, kit_text_style style,
                        vec4 plate, vec2 padding) {
    if (cue.count == 0) return vec4(0.0);
    int end = cue.first + cue.count;
    kit_text_line top = kit_text_read_line(table, h, cue.first);
    kit_text_line bottom = kit_text_read_line(table, h, end - 1);
    vec2 span = top.span;
    for (int i = cue.first + 1; i < end; ++i) {
        kit_text_line line = kit_text_read_line(table, h, i);
        span = vec2(min(span.x, line.span.x), max(span.y, line.span.y));
    }
    p += vec2(0.5 * (span.x + span.y), bottom.baseline);
    vec2 lo = vec2(span.x, top.baseline - h.em) - padding;
    vec2 hi = vec2(span.y, bottom.baseline + 0.3 * h.em) + padding;
    vec4 background = vec4(0.0);
    if (kit_private_text_in_tile(p - lo, hi - lo)) {
        background = kit_private_text_colour(plate, 1.0);
    }
    vec4 ink = kit_text_run(atlas, table, h, ivec2(cue.first, end), p, reach, spread, pixel, style);
    return kit_private_text_straight(kit_private_text_over(ink, background));
}
