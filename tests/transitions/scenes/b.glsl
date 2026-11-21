// The incoming shot of every transition: a still gradient unlike a.glsl everywhere.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = vec4(0.9 - uv.y, 0.3, 0.2 + uv.x * 0.7, 1.0);
}
