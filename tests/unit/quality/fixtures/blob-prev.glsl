// shimmer: a soft blob drifting slowly, the prev frame (30 fps).
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec2 c = vec2(0.2 * (-1.0 / 30.0) - 0.2, 0.0);
    fragColor = vec4(vec3(0.2 + 0.6 * exp(-8.0 * dot(p - c, p - c))), 1.0);
}
