// A grey ramp across the frame from 0.05 to 0.95: no pixel clipped or crushed.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float v = mix(0.05, 0.95, fragCoord.x / iResolution.x);
    fragColor = vec4(vec3(clamp(v, 0.0, 1.0)), 1.0);
}
