// exposure: a grey ramp from -0.2 to 1.3, clamped: blown out at the top, crushed at the bottom.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float v = mix(-0.2, 1.3, fragCoord.x / iResolution.x);
    fragColor = vec4(vec3(clamp(v, 0.0, 1.0)), 1.0);
}
