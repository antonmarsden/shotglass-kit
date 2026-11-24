// A soft blob drifting slowly across: smooth motion, which @prev and @next average out.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float v = 0.2 + 0.6 * exp(-8.0 * dot(p - vec2(0.2 * iTime - 0.2, 0.0), p - vec2(0.2 * iTime - 0.2, 0.0)));
    fragColor = vec4(vec3(v), 1.0);
}
