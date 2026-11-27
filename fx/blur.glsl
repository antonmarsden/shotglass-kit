// shotglass-kit/fx: blur.glsl
//
// A one-direction gaussian blur of the layer's input, 17 taps over +-3 sigma. Two of
// them (across, then down) make a separable 2D blur. The glow half of the bloom recipe:
//
//   [[layer]]                           # 1. what is bright, hidden (opacity 0)
//   id = "bright"  type = "fx/bright"  scale = 0.5  opacity = 0  channels = ["@input"]
//   [[layer]]                           # 2. blurred across, hidden
//   id = "across"  type = "fx/blur"    scale = 0.5  opacity = 0  channels = ["@bright"]
//   params = { direction = [1.0, 0.0] }
//   [[layer]]                           # 3. blurred down, screened over the picture
//   id = "bloom"   type = "fx/blur"    scale = 0.5  opacity = 0.8  channels = ["@across"]
//   blend = "blend/screen"  params = { direction = [0.0, 1.0] }  uniforms.uRadius = 0.03
//
// (blend/add makes a stronger, hotter glow.) At `scale = 0.5` the three passes
// cost a quarter of a full-size blur each.
//   channels  ["@<layer>"]               iChannel0 is the picture to blur
//   uniforms (animatable):
//     uRadius  float, frame heights      the blur's sigma (default 0.02)
//     uGain    float, >= 0               multiplies the result (default 1)
//   params:
//     direction  vec2                    (1, 0) blurs across, (0, 1) down (default 1, 0)
//   cost: 17 texture reads
//   e.g.  see the recipe above
// sound: picture only
#ifndef SG_HAS_uRadius
const float uRadius = 0.02;
#endif
#ifndef SG_HAS_uGain
const float uGain = 1.0;
#endif
#ifndef direction
#define direction vec2(1.0, 0.0)
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    // One tap step in uv: 3 sigma over 8 steps, along `direction` in frame heights.
    vec2 step_uv = normalize(vec2(direction)) * vec2(iResolution.y / iResolution.x, 1.0) * (3.0 * uRadius / 8.0);
    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (int i = -8; i <= 8; i++) {
        float x = float(i) * (3.0 / 8.0);          // distance in sigmas
        float w = exp(-0.5 * x * x);
        sum += w * texture(iChannel0, uv + step_uv * float(i)).rgb;
        total += w;
    }
    fragColor = vec4(uGain * sum / total, 1.0);
}
