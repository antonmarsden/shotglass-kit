// shotglass-kit/transitions: iris
//
// Classic cartoon iris. Opening (default): the new shot appears in a growing circle.
// Closing: the old shot shrinks into a circle and the new shot is outside it.
//   center    vec2, 0..1 of the frame   where the circle is centred (default the middle)
//   softness  in frame heights          edge blur (default 0.004)
//   closing   0 or 1                    1 = closing iris (default 0)
//   e.g.      transition = { type = "fx/iris.glsl", duration = 0.8, params = { center = [0.3, 0.6] } }
#ifndef center
#define center vec2(0.5, 0.5)
#endif
#ifndef softness
#define softness 0.004
#endif
#ifndef closing
#define closing 0.0
#endif
vec4 transition(vec2 uv) {
    vec2 a = vec2(ratio, 1.0);
    vec2 c = center * a;
    // radius that just covers the farthest corner
    float far = max(max(length(c), length(c - vec2(a.x, 0.0))),
                    max(length(c - vec2(0.0, 1.0)), length(c - a)));
    float d = length(uv * a - c);
    // The blurred edge starts and ends a softness beyond the centre and the corner, so
    // the first frame is exactly the old shot and the last exactly the new one.
    if (closing > 0.5) {
        float r = mix(far + softness, -softness, progress);
        float inside = 1.0 - smoothstep(r - softness, r + softness, d);
        return mix(getToColor(uv), getFromColor(uv), inside);
    }
    float r = mix(-softness, far + softness, progress);
    float inside = 1.0 - smoothstep(r - softness, r + softness, d);
    return mix(getFromColor(uv), getToColor(uv), inside);
}
