// Three discs on a ground, antialiased over about a pixel, every colour from the palette.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float px = 1.0 / iResolution.y;
    vec3 col = vec3(0.114, 0.169, 0.325);                      // #1d2b53
    col = mix(col, vec3(1.0, 0.0, 0.302), smoothstep(px, -px, length(p - vec2(-0.45, 0.0)) - 0.2));   // #ff004d
    col = mix(col, vec3(1.0, 0.945, 0.910), smoothstep(px, -px, length(p) - 0.2));                     // #fff1e8
    col = mix(col, vec3(1.0, 0.0, 0.302)    , smoothstep(px, -px, length(p - vec2(0.45, 0.0)) - 0.2));
    fragColor = vec4(col, 1.0);
}
