// shotglass-kit/text: number.glsl
// sound: picture only
// Draw formatted numbers with a format-1 glyph set. No shaping between characters.
// Left pen at x = 0, baseline at y = 0, in layout texels, positive y down.

#include "runs.glsl"

// Find the glyph index for a Unicode code point, or -1 when absent.
int kit_text_set_find(sampler2D table, kit_text_table h, uint code) {
    if (h.kind != 1) return -1;
    int lo = 0;
    int hi = h.glyphs;
    while (lo < hi) {
        int mid = lo + (hi - lo) / 2;
        uint key = kit_private_text_u32(table, h.first_glyph + mid * h.glyph_stride + 4);
        if (code < key) hi = mid;
        else if (code > key) lo = mid + 1;
        else return mid;
    }
    return -1;
}

// Buffers contain characters in reverse display order.
int kit_private_text_number_codes(int value, int decimals, out uint codes[16]) {
    int places = clamp(decimals, 0, 9);
    uint magnitude = value < 0 ? 0u - uint(value) : uint(value);
    int count = 0;
    for (int i = 0; i <= places || magnitude != 0u; ++i) {
        if (i > 0 && i == places) codes[count++] = 46u;
        codes[count++] = 48u + magnitude % 10u;
        magnitude /= 10u;
    }
    if (value < 0) codes[count++] = 45u;
    return count;
}

void kit_private_text_two_digits(uint value, inout uint codes[16], inout int count) {
    codes[count++] = 48u + value % 10u;
    codes[count++] = 48u + value / 10u % 10u;
}

int kit_private_text_time_codes(uint ms, out uint codes[16]) {
    int count = 0;
    codes[count++] = 48u + ms % 10u;
    kit_private_text_two_digits(ms / 10u, codes, count);
    codes[count++] = 46u;
    kit_private_text_two_digits(ms / 1000u % 60u, codes, count);
    codes[count++] = 58u;
    kit_private_text_two_digits(ms / 60000u % 60u, codes, count);
    codes[count++] = 58u;
    uint hours = ms / 3600000u;
    kit_private_text_two_digits(hours, codes, count);
    for (hours /= 100u; hours != 0u; hours /= 10u) codes[count++] = 48u + hours % 10u;
    return count;
}

vec4 kit_private_text_draw_codes(sampler2D atlas, sampler2D table, kit_text_table h,
                                 uint codes[16], int count, vec2 p, float spread,
                                 float pixel, kit_text_style style) {
    vec4 result = vec4(0.0);
    for (int i = count - 1; i >= 0; --i) {
        int index = kit_text_set_find(table, h, codes[i]);
        if (index < 0) continue;
        kit_text_glyph glyph = kit_text_read_glyph(table, h, index, 0.0);
        vec4 ink = kit_text_glyph_ink(atlas, h, glyph, p, spread, pixel,
            kit_text_motion(vec2(0.0), 1.0, 0.0, 1.0), style);
        result = kit_private_text_over(ink, result);
        p.x -= glyph.advance;
    }
    return result;
}

// Draw a signed integer (decimals = 0) or a fixed-point value in integral units
// of 10^-decimals. Decimal places clamp to 0..9. Missing characters take zero
// width. Spread and pixel follow kit_text_glyph_ink. Returns premultiplied RGBA.
vec4 kit_text_number(sampler2D atlas, sampler2D table, kit_text_table h, int value,
                    int decimals, vec2 p, float spread, float pixel, kit_text_style style) {
    uint codes[16];
    int count = kit_private_text_number_codes(value, decimals, codes);
    return kit_private_text_draw_codes(atlas, table, h, codes, count, p, spread, pixel, style);
}

// Draw nonnegative elapsed time HH:MM:SS.mmm, expanding hours beyond two digits.
// Missing characters take zero width. Returns premultiplied display RGBA.
vec4 kit_text_timecode(sampler2D atlas, sampler2D table, kit_text_table h, uint ms,
                      vec2 p, float spread, float pixel, kit_text_style style) {
    uint codes[16];
    int count = kit_private_text_time_codes(ms, codes);
    return kit_private_text_draw_codes(atlas, table, h, codes, count, p, spread, pixel, style);
}
