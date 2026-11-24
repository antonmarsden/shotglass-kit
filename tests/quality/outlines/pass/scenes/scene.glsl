// A ring drawn in ink on paper, 4 pixels wide all round (at 216 lines).
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float w = 0.0185;                                   // line width, frame heights
    float d = abs(length(p) - 0.3) - 0.5 * w;
    float px = 0.5 / iResolution.y;
    fragColor = vec4(vec3(mix(0.95, 0.05, smoothstep(px, -px, d))), 1.0);
}
