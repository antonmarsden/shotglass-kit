// shotglass-kit/quality: picture/exposure.glsl
//
// Clipped highlights and crushed blacks: the tails of the histogram where detail is
// lost. Measure per pixel: 1 where the brightest channel is at or above HIGH (clipped)
// or at or below LOW (crushed), else 0; so the mean is the share of the frame lost.
// The heatmap shows clipped pixels red, crushed ones blue.
//   params:
//     HIGH  number, 0..1  clipped from here up (default 254.5 / 255: only full scale)
//     LOW   number, 0..1  crushed from here down (default 0.5 / 255: only pure black);
//                         below 0 counts no pixel as crushed
//   typical limits: mean max 0.001-0.01; films with pure-black backgrounds or letterbox
//   bars set LOW = -1 and measure only the highlights.
//   reads: @frame
//   cost: 1 texture read
//   e.g.  [[metric]]  use = "quality/picture/exposure"  params = { LOW = -1 }  mean = { max = 0.005 }
// sound: picture only
#include "../ops.glsl"
#ifndef HIGH
#define HIGH 0.998039
#endif
#ifndef LOW
#define LOW 0.001961
#endif

void mainMetric(out vec4 value, in vec2 fragCoord) {
    vec3 c = getFrame(fragCoord / iResolution.xy).rgb;
    float top = max(c.r, max(c.g, c.b));
    float clipped = float(top >= HIGH);
    float crushed = float(top <= LOW);
    value = vec4(clipped, 0.3 * crushed, crushed, max(clipped, crushed));
}
