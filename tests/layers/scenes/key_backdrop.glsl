// A checker makes both the cleared screen and the partial source alpha visible.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 cell = floor(fragCoord / iResolution.xy * vec2(16.0, 9.0));
    float tile = mod(cell.x + cell.y, 2.0);
    fragColor = vec4(mix(vec3(0.12, 0.15, 0.22), vec3(0.28, 0.34, 0.45), tile), 1.0);
}
