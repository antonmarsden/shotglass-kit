// Something to play off tape: colour bars behind a bright ball bouncing across, with
// a red lower third sliding in and out, so the ghosts have hard, coloured, moving
// edges to trail.
#include <kit/sdf.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    vec2 p = fragCoord / iResolution.y;
    int bar = int(floor(uv.x * 7.0));
    vec3 bars[7] = vec3[7](vec3(0.75), vec3(0.75, 0.75, 0.0), vec3(0.0, 0.75, 0.75), vec3(0.0, 0.75, 0.0),
                           vec3(0.75, 0.0, 0.75), vec3(0.75, 0.0, 0.0), vec3(0.0, 0.0, 0.75));
    vec3 col = bars[clamp(bar, 0, 6)] * 0.55;
    if (uv.y < 0.25) col = vec3(0.04);
    float x = 0.2 + (aspect - 0.4) * abs(fract(iTime * 0.35) * 2.0 - 1.0);
    float y = 0.4 + 0.35 * abs(sin(iTime * 3.2));
    float ball = 1.0 - smoothstep(0.0, 2.0 / iResolution.y, kit_sd_circle(p - vec2(x, y), 0.09));
    col = mix(col, vec3(1.0, 0.95, 0.85), ball);
    // A broadcast lower third: a red band with a yellow edge and white "words" (blocks
    // standing in for text), sliding in over 0.2-1.4 s and out from 2 s, so its
    // saturated, moving edges show the chroma smear in both halves of the shot.
    float slide = smoothstep(0.2, 1.4, iTime) - smoothstep(2.0, 3.2, iTime);
    float x0 = mix(-0.9, 0.12, slide);                 // left edge of the band, frame heights
    vec2 q = p - vec2(x0, 0.0);
    float px = 1.5 / iResolution.y;
    float band = 1.0 - smoothstep(0.0, px, kit_sd_box(q - vec2(0.42, 0.13), vec2(0.42, 0.055)));
    float edge = 1.0 - smoothstep(0.0, px, kit_sd_box(q - vec2(0.012, 0.13), vec2(0.012, 0.055)));
    float words = 0.0;
    float wx = 0.07;
    for (int i = 0; i < 4; i++) {
        float w = 0.05 + 0.07 * fract(0.37 * float(i * i + 3));
        words = max(words, 1.0 - smoothstep(0.0, px, kit_sd_box(q - vec2(wx + w, 0.145), vec2(w, 0.016)) - 0.004));
        wx += 2.0 * w + 0.025;
    }
    float sub = 1.0 - smoothstep(0.0, px, kit_sd_box(q - vec2(0.2, 0.1), vec2(0.13, 0.008)));
    col = mix(col, vec3(0.75, 0.06, 0.08), band);
    col = mix(col, vec3(1.0, 0.8, 0.1), edge);
    col = mix(col, vec3(1.0), max(words, sub) * band);
    fragColor = vec4(col, 1.0);
}
