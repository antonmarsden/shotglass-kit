// Ink bleeding into damp paper: one step of a small water-and-pigment flow model, after
// Curtis et al., "Computer-Generated Watercolor" (SIGGRAPH 1997), much simplified.
// State: x water, y pigment carried in the water, z pigment settled into the paper.
//
// - Water flows between neighbouring texels down its own difference, through a
//   conductance set by the paper: fibre noise makes some paths wick faster, which
//   gives the feathery, uneven front of a real bleed. Dry paper barely conducts.
// - Pigment moves with the water, upwind (what flows out of a texel takes that texel's
//   pigment along), plus a little diffusion where it's wet.
// - Water evaporates; as a wet patch thins, its pigment settles, faster where the
//   water is shallow. The edge of a patch dries first and the flow towards it carries
//   pigment outwards, so the rim ends up darker: the "coffee ring" of real ink.
// - Drops land at fixed frames (frames since the reset, so the fold is fixed). Fresh
//   water on a drying wash lifts its settled pigment and blooms (see below).
//
// Six chained buffers give six steps per film frame (ink1 steps ink6's previous state,
// ink2..ink6 the one before them). ink1 (params.FIRST defined) also lays the damp
// paper on frame 0 and adds the drops.
#include <kit/noise.glsl>
#include <buffer/sample.glsl>

// How readily paper at p (frame heights) wicks water: 0.005..0.25 per step (at most
// 0.25, so four links stay stable). Fibres are channels of fast wicking (stretched
// noise, thresholded sharply) through slow paper, so a front runs ahead along them.
float wick(vec2 p) {
    float fibre = kit_fbm(p * vec2(10.0, 30.0), 4);
    float tooth = kit_value_noise(p * 90.0);
    float f = 0.7 * fibre + 0.3 * tooth;
    return 0.005 + 0.245 * smoothstep(0.42, 0.58, f);
}

// The state at texel q. On ink1's first frame there is none yet (ink6's previous
// state is black): the paper starts damp, a thin film of water, more in patches.
vec4 state(sampler2D s, ivec2 q) {
#ifdef FIRST
    if (iFrame == 0) {
        vec2 p = (vec2(q) + 0.5) / iResolution.y;
        return vec4(0.04 + 0.03 * kit_value_noise(p * 4.0), 0.0, 0.0, 1.0);
    }
#endif
    return kit_buf_fetch(s, q, false);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 q = ivec2(fragCoord);
    vec2 p = fragCoord / iResolution.y;
    float aspect = iResolution.x / iResolution.y;
    vec4 c = state(iChannel0, q);

    float k0 = wick(p);
    vec4 next = c;
    ivec2 nbr[4] = ivec2[4](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));
    for (int i = 0; i < 4; i++) {
        vec4 n = state(iChannel0, q + nbr[i]);
        vec2 pn = (fragCoord + vec2(nbr[i])) / iResolution.y;
        // Conductance of the link: the slower paper of the two, only where wet.
        float wet = smoothstep(0.02, 0.10, max(c.x, n.x));
        float k = min(k0, wick(pn)) * wet;
        float flow = k * (n.x - c.x);                 // water in (> 0) or out (< 0)
        next.x += flow;
        // Pigment rides with it, upwind, plus slight diffusion.
        float carried = flow > 0.0 ? n.y / max(n.x, 1e-4) : c.y / max(c.x, 1e-4);
        next.y += flow * carried + 0.02 * wet * (n.y - c.y);
    }
    // Evaporation, and settling that speeds up as the water gets shallow.
    next.x = max(next.x - 0.0006, 0.0);
    float settle = 0.012 + 0.12 * (1.0 - smoothstep(0.03, 0.2, next.x));
    float dep = next.y * settle;
    next.y -= dep;
    next.z += dep;
    // Re-wetting lifts settled pigment back into the water: when fresh water floods a
    // drying wash, it picks the pigment up and carries it to its front, where it
    // settles in a jagged dark edge round a paler centre: a bloom (backrun).
    float lift = next.z * 0.08 * smoothstep(0.2, 0.6, next.x);
    next.z -= lift;
    next.y += lift;

#ifdef FIRST
    // Drops: ink at 0, 0.5 and 1.2 s (frames 0, 15, 36 at 30 fps), each a disc of
    // water carrying pigment, then at 2 s a smaller drop of clear water into the second
    // wash while it is still damp, which blooms.
    vec4 drops[4] = vec4[4](vec4(0.40 * aspect, 0.56, 0.0, 1.5), vec4(0.62 * aspect, 0.42, 15.0, 1.5),
                            vec4(0.50 * aspect, 0.66, 36.0, 1.5), vec4(0.60 * aspect, 0.40, 60.0, 0.0));
    for (int i = 0; i < 4; i++) {
        if (iFrame == int(drops[i].z)) {
            bool clear = drops[i].w == 0.0;   // smaller and less wet: it stops inside the wash
            float d = kit_buf_seed_disc(p, drops[i].xy, clear ? 0.09 : 0.08 + 0.015 * float(i), 0.01);
            next.x += (clear ? 0.8 : 1.0) * d;
            next.y += drops[i].w * d;
        }
    }
#endif
    fragColor = vec4(next.xyz, 1.0);
}
