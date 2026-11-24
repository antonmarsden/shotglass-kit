// A ring drawn in ink on paper, whose line swells from 1.5 to 8 pixels around it.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float w = mix(0.007, 0.037, 0.5 + 0.5 * sin(3.0 * atan(p.y, p.x)));                                   // line width, frame heights
    float d = abs(length(p) - 0.3) - 0.5 * w;
    float px = 0.5 / iResolution.y;
    fragColor = vec4(vec3(mix(0.95, 0.05, smoothstep(px, -px, d))), 1.0);
}
