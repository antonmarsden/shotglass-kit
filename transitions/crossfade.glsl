// shotglass-kit/transitions: crossfade
//
// Plain cross-dissolve from the old shot to the new one.
//   params: none
//   cost:   both shots render for the whole transition (unless freeze = true)
//   e.g.    transition = { type = "fx/crossfade.glsl", duration = 0.5 }
//           with fx/crossfade.glsl: #include <transitions/crossfade.glsl>
vec4 transition(vec2 uv) {
    return mix(getFromColor(uv), getToColor(uv), progress);
}
