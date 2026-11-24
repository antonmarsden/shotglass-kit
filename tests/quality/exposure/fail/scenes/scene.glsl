// A grey ramp across the frame from -0.2 to 1.3, clamped: a quarter of it white, a tenth black.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float v = mix(-0.2, 1.3, fragCoord.x / iResolution.x);
    fragColor = vec4(vec3(clamp(v, 0.0, 1.0)), 1.0);
}
