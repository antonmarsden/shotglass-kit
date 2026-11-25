// Cellular noise used for a surface with dark seams.
#include <kit/noise.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (fragCoord / iResolution.y) * 9.0;
    vec2 distances = kit_cellular_noise(p);
    float vein = smoothstep(0.01, 0.085, distances.y - distances.x);
    vec3 surface = mix(vec3(0.08, 0.32, 0.30), vec3(0.30, 0.71, 0.57),
                       1.0 - smoothstep(0.0, 0.8, distances.x));
    fragColor = vec4(mix(vec3(0.015, 0.035, 0.04), surface, vein), 1.0);
}
