#include <text/kinetic.glsl>

void test_stagger() {
    kit_text_glyph glyph;
    glyph.grapheme = 7;
    glyph.word = 3;
    glyph.line = 2;
    expect_eq(kit_text_stagger(glyph, kit_text_by_grapheme, 1.75, 0.0, 0.25, 1.0), 0.0);
    expect_eq(kit_text_stagger(glyph, kit_text_by_word, 1.25, 0.0, 0.25, 1.0), 0.5);
    expect_eq(kit_text_stagger(glyph, kit_text_by_line, 1.5, 0.0, 0.25, 1.0), 1.0);
    expect_eq(kit_text_stagger(glyph, kit_text_by_line, 1.5, 1.0, 0.25, 0.0), 1.0);
    expect_eq(kit_text_stagger(glyph, kit_text_by_line, 1.0, 1.0, 0.25, -2.0), 0.0);
    expect_eq(kit_text_typewriter(glyph, 7), 0.0);
    expect_eq(kit_text_typewriter(glyph, 8), 1.0);
}

void test_reveal() {
    kit_text_motion start = kit_text_motion(vec2(4.0, -8.0), 2.0, 1.0, 0.0);
    kit_text_motion mid = kit_text_reveal(start, 0.5);
    expect_eq(mid.offset, vec2(2.0, -4.0));
    expect_eq(mid.scale, 1.5);
    expect_eq(mid.angle, 0.5);
    expect_eq(mid.opacity, 0.5);
    kit_text_motion end = kit_text_reveal(start, 2.0);
    expect_eq(end.offset, vec2(0.0));
    expect_eq(end.scale, 1.0);
    expect_eq(end.angle, 0.0);
    expect_eq(end.opacity, 1.0);
}
