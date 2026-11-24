// alias: a zone plate ringing finer than a pixel at the edge, one sample per pixel: moire.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    fragColor = vec4(vec3(0.5 + 0.5 * cos(600.0 * dot(p, p))), 1.0);
}
