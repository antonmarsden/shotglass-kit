#include <text/number.glsl>

uniform sampler2D uNothing;

void test_fixed_point() {
    uint codes[16];
    int n = kit_private_text_number_codes(-5, 2, codes);
    expect_eq(n, 5);
    // "-0.05", stored from right to left.
    expect(codes[0] == 53u && codes[1] == 48u && codes[2] == 46u, float(n));
    expect(codes[3] == 48u && codes[4] == 45u, float(n));
    n = kit_private_text_number_codes(0, 0, codes);
    expect_eq(n, 1);
    expect(codes[0] == 48u, float(n));
    n = kit_private_text_number_codes(-2147483647 - 1, 0, codes);
    expect_eq(n, 11);
    expect(codes[0] == 56u && codes[9] == 50u && codes[10] == 45u, float(n));
}

void test_timecode() {
    uint codes[16];
    int n = kit_private_text_time_codes(3723004u, codes);
    expect_eq(n, 12);
    // "01:02:03.004", stored from right to left.
    expect(codes[0] == 52u && codes[1] == 48u && codes[2] == 48u && codes[3] == 46u, float(n));
    expect(codes[4] == 51u && codes[5] == 48u && codes[6] == 58u, float(n));
    expect(codes[7] == 50u && codes[8] == 48u && codes[9] == 58u, float(n));
    expect(codes[10] == 49u && codes[11] == 48u, float(n));
    n = kit_private_text_time_codes(4294967295u, codes);
    expect_eq(n, 14);
}

void test_missing_set() {
    kit_text_table h = kit_text_read_table(uNothing);
    kit_text_style style = kit_text_style(vec4(1.0), vec4(0.0), vec4(0.0), 0.0, 0.0, 0.0, vec2(0.0));
    expect_eq(kit_text_number(uNothing, uNothing, h, 123, 0, vec2(0.0), 4.0, 1.0, style), vec4(0.0));
    expect_eq(kit_text_timecode(uNothing, uNothing, h, 0u, vec2(0.0), 4.0, 1.0, style), vec4(0.0));
}
