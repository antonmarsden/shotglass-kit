// Film-wide layer. Channels 0 and 1 bind the subtitle atlas and table.
#include <text/subtitles.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    kit_text_table h = kit_text_read_table(iChannel1);
    kit_text_cue cue = kit_text_find_cue(iChannel1, h, uint(max(iMovieTime, 0.0) * 1000.0));
    float pixel = max(h.em, 1.0) / (0.045 * iResolution.y);
    vec2 p = (fragCoord - vec2(0.5, 0.12) * iResolution.xy) * vec2(pixel, -pixel);
    kit_text_style style = kit_text_style(vec4(1.0), vec4(0.0), vec4(0.0), 0.0, 0.0, 0.0, vec2(0.0));
    fragColor = kit_text_subtitles(iChannel0, iChannel1, h, cue, p, vec2(2.0 * h.em),
        iChannelMeta[0].y, pixel, style, vec4(0.0, 0.0, 0.0, 0.72), vec2(0.35, 0.12) * h.em);
}
