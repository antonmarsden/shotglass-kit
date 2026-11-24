// A disc crossing the frame, animated on twos: the time holds for two frames.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float t = floor(float(iFrame) / 2.0) * 2.0 / 30.0;
    float d = length(p - vec2(0.4 * t - 0.4, 0.0)) - 0.15;
    fragColor = vec4(vec3(mix(0.9, 0.1, smoothstep(0.004, -0.004, d))), 1.0);
}
