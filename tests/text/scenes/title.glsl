// A title card: the title (Bungee, iChannel0) magnified well past the size it was
// rasterised at, with a drop shadow, a glow and an outline, its ink a gradient across
// the word, with a darker rim; under it the tagline (Inter, iChannel1), smaller than
// its raster, fading in on a faint halo.
// Both are sized by em in frame heights, so the sizes in movie.toml only set quality.
// (uIn is declared from movie.toml.)
#include <text/block.glsl>
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 col = mix(vec3(0.05, 0.05, 0.09), vec3(0.16, 0.10, 0.18), uv.y);

    // The title: 0.2 of the frame height per em, rising a little as it fades in.
    vec2 pos = vec2(0.5, 0.56 + 0.03 * uIn);
    kit_text_box t = kit_text_place(iChannelResolution[0], iChannelMeta[0], fragCoord, iResolution.xy, pos, 0.2);
    float reach = kit_text_reach(t.meta);
    float shadow = kit_text_shadow(iChannel0, t, vec2(0.05, -0.06), 0.12);
    float glow = kit_text_glow(iChannel0, t, min(0.3, reach));
    float line = kit_text_outline(iChannel0, t, 0.05);
    float ink = kit_text_edge(iChannel0, t, 0.0);
    col = mix(col, vec3(0.0), 0.7 * shadow * uIn);
    col += vec3(0.9, 0.45, 0.2) * 0.35 * glow * (1.0 - ink) * uIn;
    col = mix(col, vec3(0.08, 0.04, 0.06), line * uIn);
    vec3 fill = mix(vec3(1.0, 0.62, 0.25), vec3(1.0, 0.93, 0.7), clamp(t.local.y, 0.0, 1.0));
    // A darker rim inside the ink: the letters shrunk by 0.03 em, from the distance.
    float d = kit_text_distance(iChannel0, t);
    fill *= mix(0.78, 1.0, kit_text_ink(d - 0.03, fwidth(d)));
    col = mix(col, fill, ink * uIn);

    // The tagline: centred under the title, 0.045 frame heights per em (smaller than it
    // was rasterised), drawn from its coverage.
    kit_text_box s = kit_text_place(iChannelResolution[1], iChannelMeta[1], fragCoord, iResolution.xy, vec2(0.5, 0.22), 0.045);
    float cov = kit_text_coverage(iChannel1, s);
    // A faint dark halo around it, decoding the distance field by hand.
    float dt = kit_text_distance_em(texture(iChannel1, s.uv).g, s.meta);
    col *= 1.0 - 0.25 * smoothstep(-kit_text_reach(s.meta), 0.0, dt) * smoothstep(0.3, 1.0, uIn);
    col = mix(col, vec3(0.85, 0.82, 0.9), cov * smoothstep(0.3, 1.0, uIn));

    fragColor = vec4(kit_vignette(uv, 0.35, 0.7) * col, 1.0);
}
