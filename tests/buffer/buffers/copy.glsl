// The tape: a copy of the picture track (iChannel0), kept 6 frames deep (history = 6).
// It reads no buffer state, so it is a pure history buffer.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = vec4(texelFetch(iChannel0, ivec2(fragCoord), 0).rgb, 1.0);
}
