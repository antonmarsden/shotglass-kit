// A disc crossing the frame, animated on ones: it moves every frame.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float t = iTime;
    float d = length(p - vec2(0.4 * t - 0.4, 0.0)) - 0.15;
    fragColor = vec4(vec3(mix(0.9, 0.1, smoothstep(0.004, -0.004, d))), 1.0);
}
