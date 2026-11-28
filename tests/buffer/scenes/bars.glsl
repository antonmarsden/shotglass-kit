// Something to play off tape: colour bars behind a bright ball bouncing across, with
// a white title bar sliding in, so the ghosts have hard, moving edges to trail.
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
    float slide = clamp(iTime * 1.5 - 0.5, 0.0, 1.0);
    float title = 1.0 - smoothstep(0.0, 1.5 / iResolution.y,
                                   kit_sd_box(p - vec2(mix(-0.5, 0.5, slide) * aspect + 0.0, 0.12), vec2(0.45, 0.04)));
    col = mix(col, vec3(1.0), title);
    fragColor = vec4(col, 1.0);
}
