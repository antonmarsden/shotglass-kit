// A lit ball on a flat ground, toon-shaded: three flat levels, antialiased between.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y / 0.4;
    float r2 = dot(p, p);
    vec3 n = vec3(p, sqrt(max(1.0 - r2, 0.0)));
    float light = max(dot(n, normalize(vec3(-0.5, 0.6, 0.7))), 0.0);
    float s = light * 3.0;
    light = (floor(s) + smoothstep(1.0 - fwidth(s), 1.0, fract(s))) / 3.0;   // three flat bands, antialiased
    float edge = 1.0 / (0.4 * iResolution.y);
    fragColor = vec4(vec3(mix(0.2, 0.15 + 0.75 * light, smoothstep(edge, -edge, sqrt(r2) - 1.0))), 1.0);
}
