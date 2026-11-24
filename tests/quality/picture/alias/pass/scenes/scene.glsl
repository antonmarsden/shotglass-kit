// A zone plate, rings a few pixels wide even at the edge: nothing for the reference to smooth.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float v = 0.5 + 0.5 * cos(20.0 * dot(p, p));
    fragColor = vec4(vec3(v), 1.0);
}
