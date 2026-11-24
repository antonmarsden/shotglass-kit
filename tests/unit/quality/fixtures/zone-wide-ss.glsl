// alias: the same zone plate, 4x4 samples per pixel (its @reference).
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float v = 0.0;
    for (int i = 0; i < 16; i++) {
        vec2 q = (fragCoord + (vec2(float(i % 4), float(i / 4)) + 0.5) / 4.0 - 0.5 - 0.5 * iResolution.xy) / iResolution.y;
        v += 0.5 + 0.5 * cos(20.0 * dot(q, q));
    }
    fragColor = vec4(vec3(v / 16.0), 1.0);
}
