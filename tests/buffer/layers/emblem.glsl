// A neon emblem in front of the camera: a turning triangle inside a ring, swinging
// gently, drawn on transparent (premultiplied). It falls into the feedback tunnel.
#include <kit/sdf.glsl>

float tri(vec2 p, float r) {
    // Equilateral triangle outline, circumradius r.
    float d = -1e9;
    for (int i = 0; i < 3; i++) {
        float a = 6.28318531 * float(i) / 3.0 + 1.5707963;
        d = max(d, dot(p, vec2(cos(a), sin(a))) - 0.5 * r);
    }
    return abs(d) - 0.006;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    p -= vec2(0.12 * sin(iTime * 1.3), 0.06 * sin(iTime * 2.1));
    float a = 0.8 * iTime;
    vec2 q = mat2(cos(a), sin(a), -sin(a), cos(a)) * p;
    float ring = abs(kit_sd_circle(p, 0.26)) - 0.006;
    float d = min(ring, tri(q, 0.4));
    float px = 1.0 / iResolution.y;
    float line = 1.0 - smoothstep(0.0, 1.5 * px, d);
    float glow = 0.4 * exp2(-max(d, 0.0) / (8.0 * px));
    vec3 neon = mix(vec3(1.0, 0.2, 0.6), vec3(0.2, 0.9, 1.0), 0.5 + 0.5 * sin(iTime));
    float alpha = clamp(line + glow, 0.0, 1.0);
    fragColor = vec4(neon * alpha + vec3(line) * 0.6, alpha);
}
