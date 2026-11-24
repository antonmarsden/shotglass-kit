// outlines: a ring drawn in ink, its line 4 px wide all round at 108 lines.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float w = 4.0 / 108.0;                                   // line width, frame heights
    float d = abs(length(p) - 0.3) - 0.5 * w;
    float px = 0.5 / iResolution.y;
    fragColor = vec4(vec3(mix(0.95, 0.05, smoothstep(px, -px, d))), 1.0);
}
