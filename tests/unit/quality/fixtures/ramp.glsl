// banding: a slow grey ramp, 0.3 to 0.4 across, undithered: bands about 8 pixels wide at 192.
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float v = mix(0.3, 0.4, fragCoord.x / iResolution.x);

    fragColor = vec4(vec3(v), 1.0);
}
