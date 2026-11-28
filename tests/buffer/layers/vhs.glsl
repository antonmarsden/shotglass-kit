// VHS playback: luma from the tape now (iChannel0), chroma smeared sideways and
// trailing (a box blur of now plus fading echoes 2, 4 and 6 frames back, iChannel1-3,
// weighed by kit_buf_decay so the ghosts halve every 0.25 s), a wobbling line offset,
// scanlines and a tracking band. Colour is display RGB, mixed as such like the real
// thing.
#include <kit/noise.glsl>
#include <buffer/sample.glsl>

const mat3 TO_YIQ = mat3(0.299, 0.596, 0.211, 0.587, -0.274, -0.523, 0.114, -0.322, 0.312);
const mat3 TO_RGB = mat3(1.0, 1.0, 1.0, 0.956, -0.272, -1.106, 0.621, -0.647, 1.703);

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 size = vec2(textureSize(iChannel0, 0));
    float line = floor(uv.y * size.y);
    float wobble = 0.004 * (kit_value_noise(vec2(line * 0.15, float(iFrame) * 0.7)) - 0.5);
    float band = smoothstep(0.03, 0.0, abs(uv.y - fract(0.9 - 0.21 * iTime)));
    vec2 u = uv + vec2(wobble + 0.02 * band, 0.0);
    float y = (TO_YIQ * kit_buf_sample(iChannel0, u, false).rgb).x;
    vec2 cu = u - vec2(0.012, 0.0);                    // chroma lags behind luma
    vec3 now = kit_buf_box(iChannel0, ivec2(cu * size), false).rgb;
    vec3 chroma = TO_YIQ * now;
    float f = kit_buf_decay(0.25, 2.0 * iTimeDelta);   // per echo: 2 frames apart
    float w = f;
    chroma += w * (TO_YIQ * kit_buf_sample(iChannel1, cu - vec2(0.01, 0.0), false).rgb); w *= f;
    chroma += w * (TO_YIQ * kit_buf_sample(iChannel2, cu - vec2(0.02, 0.0), false).rgb); w *= f;
    chroma += w * (TO_YIQ * kit_buf_sample(iChannel3, cu - vec2(0.03, 0.0), false).rgb);
    chroma /= 1.0 + f + f * f + f * f * f;
    vec3 col = TO_RGB * vec3(y, chroma.yz * 1.3);
    col *= 0.9 + 0.1 * sin(fragCoord.y * 3.14159265);
    col += band * 0.25 * kit_hash(ivec3(ivec2(fragCoord), iFrame));
    col += 0.04 * (kit_hash(ivec3(ivec2(fragCoord) / 2, iFrame)) - 0.5);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
