// banding: the same ramp with a one-level triangular dither: no flat runs.
float hash(ivec2 c) {
    uint h = uint(c.x) * 0x8da6b343U ^ uint(c.y) * 0xd8163841U;
    h = (h ^ (h >> 16)) * 0x7feb352dU;
    h = (h ^ (h >> 15)) * 0x846ca68bU;
    return float(h ^ (h >> 16)) / 4294967296.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float v = mix(0.3, 0.4, fragCoord.x / iResolution.x);
    ivec2 c = ivec2(fragCoord);
    v += (hash(c) + hash(c + ivec2(7919, 104729)) - 1.0) / 255.0;
    fragColor = vec4(vec3(v), 1.0);
}
