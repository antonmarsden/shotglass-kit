// Identical static ramp and coloured glow for the plain and dithered shots.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 q = (uv - vec2(0.5, 0.25)) * vec2(iResolution.x / iResolution.y, 2.0);
    vec3 glow = vec3(0.95, 0.55, 0.25) * exp(-10.0 * dot(q, q));
    vec3 col = uv.y >= 0.5 ? vec3(uv.x) : glow;

    // Match the 8-bit input to the pass before plain rounding to the same 16 levels.
    col = floor(col * 255.0 + 0.5) / 255.0;
    if (uRound > 0.5) {
        col = floor(col * 15.0 + 0.5) / 15.0;
    }
    fragColor = vec4(col, 1.0);
}
