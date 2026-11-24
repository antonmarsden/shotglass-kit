// exposure: a grey ramp from 0.05 to 0.95: nothing clipped or crushed.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float v = mix(0.05, 0.95, fragCoord.x / iResolution.x);
    fragColor = vec4(vec3(clamp(v, 0.0, 1.0)), 1.0);
}
