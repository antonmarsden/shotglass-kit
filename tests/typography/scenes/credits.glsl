#include <text/runs.glsl>
#include <text/number.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    kit_text_table h = kit_text_read_table(iChannel1);
    kit_text_line first = kit_text_read_line(iChannel1, h, 0);
    kit_text_line last = kit_text_read_line(iChannel1, h, h.lines - 1);
    float pixel = h.em / (0.065 * iResolution.y);
    vec2 p = (fragCoord - vec2(0.5, 0.0) * iResolution.xy) * vec2(pixel, -pixel);
    p += vec2(0.5 * (first.span.x + first.span.y),
              mix(first.baseline - h.em, last.baseline + h.em + iResolution.y * pixel, iShotProgress));
    kit_text_style style = kit_text_style(vec4(1.0, 0.91, 0.78, 1.0), vec4(0.0),
        vec4(0.0), 0.0, 0.0, 0.0, vec2(0.0));
    vec4 credits = kit_text_run(iChannel0, iChannel1, h, ivec2(0, h.lines), p,
        vec2(2.0 * h.em), iChannelMeta[0].y, pixel, style);

    kit_text_table digits = kit_text_read_table(iChannel3);
    float small_pixel = digits.em / (0.039 * iResolution.y);
    vec2 q = (fragCoord - vec2(0.06, 0.88) * iResolution.xy) * vec2(small_pixel, -small_pixel);
    vec4 timer = vec4(0.0);
    if (kit_text_set_find(iChannel3, digits, 48u) >= 0) {
        timer = kit_text_timecode(iChannel2, iChannel3, digits, uint(iMovieTime * 1000.0),
            q, iChannelMeta[2].y, small_pixel, style);
        vec4 count = kit_text_number(iChannel2, iChannel3, digits, int(iShotTime * 100.0), 2,
            q - vec2(0.0, digits.pitch), iChannelMeta[2].y, small_pixel, style);
        timer = count + timer * (1.0 - count.a);
    }
    vec3 col = credits.rgb + (1.0 - credits.a) * vec3(0.045, 0.07, 0.1);
    fragColor = vec4(timer.rgb + (1.0 - timer.a) * col, 1.0);
}
