// Two side-by-side tiles warped by curl noise, looping once per shot.
#include <kit/noise.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 p = uv * vec2(12.0, 4.0);
    float angle = 6.28318531 * iShotProgress;
    ivec2 period = ivec2(6, 4);
    vec2 unused;
    float flow = kit_simplex_flow(p, period, angle, unused);
    vec2 curl = kit_curl_noise(p, period, angle);
    float detail = kit_simplex_flow(2.0 * p + 0.16 * curl, 2 * period, angle, unused);
    float ink = smoothstep(-0.45, 0.65, flow + 0.35 * detail);
    fragColor = vec4(mix(vec3(0.025, 0.045, 0.13), vec3(0.42, 0.81, 0.91), ink), 1.0);
}
