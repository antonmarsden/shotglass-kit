// shotglass-kit/text: kinetic.glsl
// sound: picture only
// Deterministic kinetic type from the table's logical grapheme and word indices
// or visual line indices. Uses the eases in the core peer library.

#include "runs.glsl"
#include <shotglass-kit/core/ease.glsl>

const int kit_text_by_grapheme = 0;
const int kit_text_by_word = 1;
const int kit_text_by_line = 2;

int kit_private_text_stagger_index(kit_text_glyph g, int by) {
    if (by == kit_text_by_line) return g.line;
    if (by == kit_text_by_word) return g.word;
    return g.grapheme;
}

// Ease from 0 to 1, starting at start + index * interval. All times are seconds.
// Negative intervals are treated as zero. A nonpositive duration makes a step.
float kit_text_stagger(kit_text_glyph g, int by, float t, float start, float interval, float duration) {
    float at = start + float(kit_private_text_stagger_index(g, by)) * max(interval, 0.0);
    return kit_ease_smooth(kit_tween(0.0, max(duration, 0.0), t - at));
}

// Typewriter opacity for a prefix of `visible` logical graphemes.
float kit_text_typewriter(kit_text_glyph g, int visible) {
    return g.grapheme < visible ? 1.0 : 0.0;
}

// Interpolate toward rest. Offset is in layout texels, angle in clockwise radians,
// and progress clamps to 0..1. The transform is applied around each glyph origin.
kit_text_motion kit_text_reveal(kit_text_motion from, float progress) {
    float x = clamp(progress, 0.0, 1.0);
    return kit_text_motion(from.offset * (1.0 - x), mix(from.scale, 1.0, x),
                           from.angle * (1.0 - x), mix(from.opacity, 1.0, x));
}
