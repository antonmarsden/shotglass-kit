// What the blend modes blend: a vertical rainbow whose alpha rises from 0 on the left to
// 1 on the right, so every mode is seen at every coverage (straight alpha, as
// mainImage writes it; the engine premultiplies, and the blend passes undo that).
vec3 hue(float h) { return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float inset = step(0.12, uv.y) * step(uv.y, 0.88) * step(0.05, uv.x) * step(uv.x, 0.95);
    fragColor = vec4(mix(vec3(uv.y), hue(uv.y * 0.85), 0.9), smoothstep(0.05, 0.95, uv.x) * inset);
}
