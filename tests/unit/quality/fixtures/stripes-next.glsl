// shimmer: hard stripes 2.3 px apart sliding 0.9 px a frame, point-sampled, the next frame: they crawl.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float v = step(0.5, fract((fragCoord.x + fragCoord.y * 0.3 + 0.9 * 1.0) / 2.3));
    fragColor = vec4(vec3(v), 1.0);
}
