// The outgoing shot of every transition: a still gradient (time doesn't matter, so the
// same picture at any time). Red rises left to right, green bottom to top.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = vec4(uv.x, uv.y, 0.25, 1.0);
}
