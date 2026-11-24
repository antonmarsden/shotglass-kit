// Hard stripes 2.3 pixels apart sliding 0.9 pixels a frame, one sample per pixel: they crawl.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float v = step(0.5, fract((fragCoord.x + fragCoord.y * 0.3 + 0.9 * float(iFrame)) / 2.3));
    fragColor = vec4(vec3(v), 1.0);
}
