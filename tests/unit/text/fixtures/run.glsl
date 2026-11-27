// Two format-1 lines, two cues and three glyphs. Glyph 1 starts on table row 1.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int at = int(fragCoord.y) * 1024 + int(fragCoord.x);
    uint word = 0u;
    if (at == 0) word = 0x00010000u;
    if (at == 1) word = 3u;
    if (at == 2) word = 2u;
    if (at == 3) word = 12u;
    if (at == 4) word = 1018u;
    if (at == 5) word = 0x04000200u; // em 64, atlas em 32
    if (at == 6) word = 0x04000140u; // spread 4, pitch 20
    if (at == 7) word = 0x00040006u;
    if (at == 8) word = 2u;
    if (at == 9) word = 20u;
    if (at == 10) word = 0x00040000u;
    if (at == 12) word = 20u * 256u;
    if (at == 13) word = 0x00000002u;
    if (at == 14) word = 0x00100280u;
    if (at == 16) word = 40u * 256u;
    if (at == 17) word = 0x00020001u;
    if (at == 18) word = 0x00000100u;
    if (at == 20) word = 250u;
    if (at == 21) word = 500u;
    if (at == 22) word = 1u;
    if (at == 24) word = 500u;
    if (at == 25) word = 1000u;
    if (at == 26) word = 0x00010001u;
    if (at == 1018) word = 0x00a8ffecu; // pen 10.5, y offset -1.25
    if (at == 1019) word = 0x00640001u; // tile at (100, 1)
    if (at == 1020) word = 0x00040001u;
    if (at == 1021) word = 0xfff00020u; // bearing (-1, 2) atlas texels
    if (at == 1022) word = 0x00070003u; // grapheme 7, word 3
    if (at == 1023) word = 0x0000fff8u; // line 0, x offset -0.5
    if (at == 1024) word = 0x01800000u; // pen 24; glyph has no ink
    if (at == 1029) word = 0x00000004u;
    if (at == 1035) word = 0x00010000u;
    // Use the same texture as the atlas, with differing RGB and alpha distances.
    if (at >= 1124 && at < 1128) word = 0xffbf0000u;
    if (at == 1124) word = 0xff7800ffu;
    fragColor = vec4((uvec4(word) >> uvec4(24, 16, 8, 0)) & 255u) / 255.0;
}
