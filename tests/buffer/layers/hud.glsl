// A camcorder viewfinder above the tunnel: corner brackets, a blinking record dot and
// a battery icon. It is above the buffer's `after` layer, so it never feeds back: it
// stays single and sharp while everything below it spirals.
#include <kit/sdf.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float aspect = iResolution.x / iResolution.y;
    vec2 p = fragCoord / iResolution.y;
    float px = 1.0 / iResolution.y;
    // Corner brackets.
    vec2 m = vec2(0.06);
    vec2 aq = vec2(abs(p.x - 0.5 * aspect), abs(p.y - 0.5));
    vec2 c = vec2(0.5 * aspect, 0.5) - m;
    float corner = kit_sd_box(aq - c + vec2(0.04, 0.0), vec2(0.04, 0.003));
    corner = min(corner, kit_sd_box(aq - c + vec2(0.0, 0.04), vec2(0.003, 0.04)));
    float white = 1.0 - smoothstep(0.0, px, corner);
    // Battery, top right.
    vec2 b = p - vec2(aspect - 0.17, 0.89);
    float batt = abs(kit_sd_box(b, vec2(0.035, 0.015))) - 0.002;
    batt = min(batt, kit_sd_box(b - vec2(0.04, 0.0), vec2(0.004, 0.007)));
    batt = min(batt, kit_sd_box(b + vec2(0.01, 0.0), vec2(0.02, 0.009)));
    white = max(white, 1.0 - smoothstep(0.0, px, batt));
    // Record dot, top left, blinking once a second.
    float on = step(fract(iTime), 0.6);
    float rec = (1.0 - smoothstep(0.0, px, kit_sd_circle(p - vec2(0.14, 0.89), 0.016))) * on;
    vec3 col = vec3(white) + vec3(1.0, 0.1, 0.1) * rec;
    float a = max(white, rec);
    fragColor = vec4(col * 0.9, a * 0.9);
}
