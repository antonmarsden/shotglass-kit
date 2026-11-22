// The picture the layers work on: colour in the top two thirds (a hue sweep that
// brightens upwards, a few soft shapes), a grey ramp along the bottom, and some bright
// moving dots for the bloom to catch.
vec3 hue(float h) { return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec3 col = mix(vec3(0.5), hue(uv.x), 0.55) * mix(0.35, 0.9, uv.y);
    col = mix(col, vec3(0.9, 0.85, 0.7), smoothstep(0.2, 0.19, length(p - vec2(-0.45, 0.1))) * 0.8);
    col = mix(col, vec3(0.15, 0.2, 0.35), smoothstep(0.13, 0.12, abs(p.x - 0.1)) * step(0.0, p.y - 0.0));
    if (uv.y < 0.28) col = vec3(uv.x);                                 // grey ramp
    for (int i = 0; i < 4; i++) {
        float a = float(i) * 1.5708 + iTime * 0.5;
        vec2 c = vec2(0.5 * cos(a), 0.18 + 0.1 * sin(a * 1.3));
        col += vec3(1.0, 0.8, 0.5) * smoothstep(0.03, 0.015, length(p - c));
    }
    fragColor = vec4(col, 1.0);
}
