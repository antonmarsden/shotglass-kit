// A zone plate, ringing finer than a pixel towards the edge, one sample per pixel: moire.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float v = 0.5 + 0.5 * cos(1500.0 * dot(p, p));
    fragColor = vec4(vec3(v), 1.0);
}
