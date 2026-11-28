// Camera pointed at its own monitor: the previous state (iChannel0) shrunk and turned
// a little about the centre each frame (kit_buf_zoom), its colours rotated a step
// round the hue circle and faded with a half-life, under the brighter of the composite
// so far (iChannel1: stage and emblem, steps after = "emblem"). Red is read from a
// slightly stronger zoom (kit_buf_zoom_uv) for the fringe a real lens adds. Constant
// zoom and angle: feedback magnifies rounding, so nothing here varies per frame.
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 c = vec2(0.5);
    vec4 prev = kit_buf_zoom(iChannel0, uv, c, 0.9, 0.08, 0.02);
    vec2 qr = kit_buf_zoom_uv(uv, c, 0.89, 0.08, iResolution.x / iResolution.y);
    prev.r = kit_buf_sample(iChannel0, qr, false).r * kit_buf_edge_fade(qr, 0.02);
    // A hue step: rotation of 0.25 rad about the grey axis (Rodrigues, constants).
    const float k1 = 0.9792749;   // cos 0.25 + (1 - cos 0.25) / 3
    const float k2 = 0.0103625;   // (1 - cos 0.25) / 3
    const float k3 = 0.1428388;   // sin 0.25 / sqrt 3
    mat3 hue = mat3(k1, k2 + k3, k2 - k3,
                    k2 - k3, k1, k2 + k3,
                    k2 + k3, k2 - k3, k1);
    // Faded with a half-life, minus a floor so the dim stage doesn't build up.
    vec3 echo = max(hue * prev.rgb * kit_buf_decay(0.6, iTimeDelta) - 0.02, 0.0);
    vec3 now = texture(iChannel1, uv).rgb;
    fragColor = vec4(max(now, echo), 1.0);
}
