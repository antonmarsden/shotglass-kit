// A lit ball on a flat ground, with smooth Lambert shading.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y / 0.4;
    float r2 = dot(p, p);
    vec3 n = vec3(p, sqrt(max(1.0 - r2, 0.0)));
    float light = max(dot(n, normalize(vec3(-0.5, 0.6, 0.7))), 0.0);
    // smooth
    float edge = 1.0 / (0.4 * iResolution.y);
    fragColor = vec4(vec3(mix(0.2, 0.15 + 0.75 * light, smoothstep(edge, -edge, sqrt(r2) - 1.0))), 1.0);
}
