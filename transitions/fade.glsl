// shotglass-kit/transitions: fade
//
// Fade out to a colour, then fade in. Only one shot is visible at a time,
// so combined with freeze = true it costs about one normal frame.
//   color  vec3, 0..1     the colour in the middle (default black)
//   hold   0..0.9         fraction of the transition spent fully on the colour (default 0)
//   e.g.   transition = { type = "fx/fade.glsl", duration = 1.0, params = { hold = 0.2 } }
#ifndef color
#define color vec3(0.0)
#endif
#ifndef hold
#define hold 0.0
#endif
vec4 transition(vec2 uv) {
    float h = clamp(hold, 0.0, 0.9);
    float a = 0.5 - 0.5 * h, b = 0.5 + 0.5 * h;
    if (progress < a) return vec4(mix(getFromColor(uv).rgb, color, progress / a), 1.0);
    if (progress < b) return vec4(color, 1.0);
    return vec4(mix(color, getToColor(uv).rgb, (progress - b) / (1.0 - b)), 1.0);
}
