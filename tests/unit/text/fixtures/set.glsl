// Sorted set containing '-', '0', '1' and U+1F600.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    int at = int(fragCoord.x);
    uint word = 0u;
    if (at == 0) word = 0x00010001u;
    if (at == 1) word = 4u;
    if (at == 3 || at == 4) word = 12u;
    if (at == 5) word = 0x02000200u;
    if (at == 6) word = 0x04000200u;
    if (at == 7) word = 0x00040006u;
    if (at == 10) word = 0x00040000u;
    if (at >= 12 && at < 36 && (at - 12) % 6 == 4) {
        uint codes[4] = uint[4](45u, 48u, 49u, 0x1f600u);
        word = codes[(at - 12) / 6];
    }
    if (at == 19 || at == 25) word = 0x00640000u;
    if (at == 20 || at == 26) word = 0x00020001u;
    if (at == 21 || at == 27) word = 0x00000020u;
    if (at == 100 || at == 101) word = 0xffffffffu;
    if (at == 23) word = 0x00b8fff0u; // '0' advance 11.5, x offset -1
    if (at == 29) word = 0x00800000u; // '1' advance 8
    fragColor = vec4((uvec4(word) >> uvec4(24, 16, 8, 0)) & 255u) / 255.0;
}
