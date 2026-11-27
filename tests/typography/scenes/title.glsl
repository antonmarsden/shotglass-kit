#include <text/runs.glsl>
#include <text/kinetic.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    kit_text_table h = kit_text_read_table(iChannel1);
    kit_text_line first = kit_text_read_line(iChannel1, h, 0);
    float pixel = h.em / (0.12 * iResolution.y);
    vec2 p = (fragCoord - vec2(0.5, 0.57) * iResolution.xy) * vec2(pixel, -pixel);
    p += vec2(0.5 * (first.span.x + first.span.y), first.baseline);

    kit_text_style style = kit_text_style(vec4(1.0, 0.88, 0.55, 1.0),
        vec4(0.5, 0.19, 0.08, 1.0), vec4(0.0, 0.0, 0.0, 0.8), 1.5, 0.5, 3.0, vec2(2.0, 4.0));
    vec4 title = vec4(0.0);
    ivec2 rows = kit_text_run_lines(iChannel1, h, ivec2(0, h.lines), p.y, 3.0 * h.em);
    for (int row = rows.x; row < rows.y; ++row) {
        kit_text_line line = kit_text_read_line(iChannel1, h, row);
        ivec2 glyphs = kit_text_run_glyphs(iChannel1, h, line, p.x, 3.0 * h.em);
        for (int i = glyphs.x; i < glyphs.y; ++i) {
            kit_text_glyph g = kit_text_read_glyph(iChannel1, h, i, line.baseline);
            float x = kit_text_stagger(g, kit_text_by_grapheme, iShotTime, 0.15, 0.075, 0.7);
            kit_text_motion motion = kit_text_reveal(kit_text_motion(vec2(0.0, 0.65 * h.em),
                0.65, 0.18, 0.0), x);
            motion.opacity *= kit_text_typewriter(g, int(max(0.0, iShotTime) * 15.0) + 1);
            vec4 ink = kit_text_glyph_ink(iChannel0, h, g, p, iChannelMeta[0].y, pixel, motion, style);
            title = ink + title * (1.0 - ink.a);
        }
    }
    fragColor = vec4(title.rgb + (1.0 - title.a) * vec3(0.13, 0.065, 0.09), 1.0);
}
