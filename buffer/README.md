# shotglass-kit/buffer

Helpers for [feedback buffers](https://github.com/antonmarsden/shotglass/blob/main/docs/buffers.md)
(`[[buffer]]`: state kept from one frame to the next): trails with a half-life,
neighbourhoods and Laplacians, zoom and advection feedback, reaction-diffusion, the
wave equation, cellular automata, seeds for reset frames and packing state into 8-bit
channels. Needs shotglass 0.1.11 (buffers in comps, `loop = "warm"`, `after`).

```toml
# shotglass.toml
[libraries]
kit = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "core" }
buffer = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "buffer" }
```

```glsl
// buffers/trail.glsl, channels = ["@prev", "@spark"]: a light trail that halves every 0.5 s
#include <buffer/sample.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    ivec2 p = ivec2(fragCoord);
    fragColor = kit_buf_trail(kit_buf_fetch(iChannel0, p, false),
                              kit_buf_fetch(iChannel1, p, false), 0.5, iTimeDelta);
}
```

Two files: [`math.glsl`](math.glsl) is the maths on plain values (unit-tested in
[`tests/unit/buffer`](../tests/unit/buffer)); [`sample.glsl`](sample.glsl) reads state
from a sampler (`iChannelN` bound to `"@prev"`, `"@<buffer>"` or a `frame = -k`
history) and includes `math.glsl`. Every function's header gives its units, ranges and
an example.

## Determinism

A buffer's state at frame n is the fold of one step per film frame from its last reset
(shotglass's buffer docs, "Determinism and seeking"), and playback, `still`, `export`
and `strip` all show that same fold. The helpers keep it that way:

- **Frame-based.** Time enters only as `dt`, the step's length in seconds. Pass
  `iTimeDelta`, which shotglass makes exactly `1/fps` in a buffer. A half-life in
  seconds then gives the same fade at 24 or 60 fps (`kit_buf_decay`). Counters and
  schedules (a drop every 5 frames, a Life generation every 4) use `iFrame`, which in a
  buffer counts frames since the reset.
- **No render scale.** Sizes come from `textureSize` of the state, which is the
  buffer's own `size` or `scale`, never the player's auto scale.
- **Exact reads.** All reads are `texelFetch`: bilinear reads (`kit_buf_sample`,
  `kit_buf_zoom`, `kit_buf_advect`) are four fetches mixed in the shader, so float state
  (read with nearest filtering) and rgba8 state behave the same on every driver.
- **Feedback magnifies rounding.** Keep zoom, angle and rates constant over a fold;
  GPUs that differ by one ULP per step drift apart over a long fold, so compare long
  folds on one machine.
- **Randomness** comes from `kit_hash` (`kit_buf_seed_noise`), so seeds have the same
  bits on every GPU.

## Functions

| function | file | what it does |
|---|---|---|
| `kit_buf_decay(halfLife, dt)` | math | per-step factor that halves every `halfLife` seconds |
| `kit_buf_trail(prev, elem, halfLife, dt)` | math | brighter of the element and the decayed state (light painting) |
| `kit_buf_expose(prev, light, dt)` | math | long exposure: adds the light of each step (light painting) |
| `kit_buf_trail_over(prev, elem, halfLife, dt)` | math | premultiplied element over the decayed state (smoke, paint) |
| `kit_buf_laplacian(c, e, w, n, s)` | math | 5-point Laplacian |
| `kit_buf_laplacian(c, edges, corners)` | math | 9-point isotropic Laplacian |
| `kit_buf_wave(cur, prev, lap, speed, halfLife, dt)` | math | damped wave equation step (ripples, from history) |
| `kit_buf_gray_scott(ab, lap, fk)` | math | Gray-Scott reaction-diffusion step |
| `kit_buf_gs_coral()`, `_mitosis()`, `_maze()`, `_spots()`, `_waves()` | math | Gray-Scott presets, `vec2(feed, kill)` |
| `kit_buf_life(alive, neighbours)` | math | Conway's rule |
| `kit_buf_zoom_uv(uv, center, zoom, angle, aspect)` | math | where zoom-rotate feedback reads from |
| `kit_buf_advect_uv(uv, vel, dt)` | math | semi-Lagrangian back-trace |
| `kit_buf_edge_fade(uv, width)` | math | weight that keeps feedback from smearing in at the edges |
| `kit_buf_seed_disc(p, c, r, softness)` | math | soft disc for an init pass or a splat |
| `kit_buf_seed_noise(cell, seed, density)` | math | sparse random seeds per texel |
| `kit_buf_drop(p, c, r)` | math | Gaussian bump to splash into a wave |
| `kit_buf_pack_signed` / `kit_buf_unpack_signed` | math | signed values in rgba8 |
| `kit_buf_pack16` / `kit_buf_unpack16` | math | 16 bits over two rgba8 channels |
| `kit_buf_fetch(s, p, wrap)` | sample | texel-exact read, wrapped or clamped |
| `kit_buf_laplacian(s, p, wrap)` | sample | 9-point Laplacian of the state |
| `kit_buf_neighbours(s, p, wrap)` | sample | sum of the 8 neighbours |
| `kit_buf_gradient(s, p, wrap, w)` | sample | gradient of a weighted channel sum |
| `kit_buf_blur(s, p, wrap)`, `kit_buf_box(s, p, wrap)` | sample | 3x3 binomial and box blur |
| `kit_buf_sample(s, uv, wrap)` | sample | bilinear read from four fetches |
| `kit_buf_zoom(s, uv, center, zoom, angle, fade)` | sample | zoom-rotate feedback read (video feedback tunnel) |
| `kit_buf_advect(s, uv, vel, dt, wrap)` | sample | the state carried along a velocity field |

### Precision of packed state

| format | stores | precision |
|---|---|---|
| `rgba8` | 0..1 per channel | 1/255 |
| `rgba8` + `kit_buf_pack_signed(v, range)` | -range..range | range/127.5 |
| `rgba8` + `kit_buf_pack16` (two channels) | 0..1 | 1/65535 |
| `rgba16f` (default) | signed, any size | about 3 decimal digits |
| `rgba32f` | signed | float32: use it for simulations |

Both packings are linear in the stored channels, so a Laplacian or gradient of the
packed channels, weighed, is the Laplacian or gradient of the value
([`tests/buffer/buffers/wave.glsl`](../tests/buffer/buffers/wave.glsl)).

## Recipes, in the showcase films

[`tests/buffer`](../tests/buffer) (one shot each) and
[`tests/buffer-loop`](../tests/buffer-loop):

- **Light painting / long exposure:** the state is the exposure, and each frame adds
  its light (`kit_buf_expose`), so crossings burn out to white and nothing fades. The
  head's light is spread along the path it covered that frame (brighter where the hand
  slows down). Sparks are stateless ballistic paths from hashed birth times that fork
  and cool from white to red, each frame drawing the stretch it covered. The sparkler
  burns out and the shot holds the finished photograph.
- **Ink bleeding into paper:** Gray-Scott, with **eight chained buffers for eight steps
  per frame** (`rd1` reads `rd8`'s previous state, `rd2..rd8` the one before them).
  The reset reseeds with another layout and preset. Note that `init` replaces `@prev`
  on the reset frame: the first buffer in a chain also reads `@prev` and steps it then.
- **Raindrops on a pool:** the wave equation from `@prev` and `frame = -2` (`history =
  2`), with the height packed into rgba8 at 16 bits, refracting the tiles by its
  gradient.
- **Video feedback tunnel:** a buffer `after = "emblem"` reads the composite so far and
  its own state through `kit_buf_zoom`, with a hue step per pass; the HUD layer above it
  never feeds back.
- **VHS ghosting:** a pure history buffer of the picture (`history = 6`) with chroma
  echoes weighed by `kit_buf_decay`.
- **CRT phosphor:** Life on a 48x30 torus, drawn into a phosphor buffer with a
  half-life per channel (green lingers).
- **Seamless smoke loop (`loop = "warm"`):** density advected through a curl-noise field
  that turns once per period; its half-life is short against the period, so the warm
  seam carries the smoke over with no jump.
