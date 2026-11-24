// alias: a zone plate whose rings stay several pixels wide, one sample per pixel.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    fragColor = vec4(vec3(0.5 + 0.5 * cos(20.0 * dot(p, p))), 1.0);
}
