# shotglass-kit

Versioned GLSL libraries for [shotglass](https://github.com/antonmarsden/shotglass)
films. Films are assembled from tested parts instead of written from scratch, and
each film pins the exact kit version it was made with, so a new kit release never
changes a finished film.

Each folder is a separate library that a film picks (and pins) on its own:

| folder | canonical name | what's in it |
|---|---|---|
| [`core/`](core) | `shotglass-kit/core` | eases, cartoon animation (back, elastic and bounce eases, squash and stretch, anticipation and settle, held keyed poses, animating on twos), deterministic hashes and noise (value, gradient, simplex, cellular), colour (tonemapping, sRGB, palettes, vignette, grain), signed distance shapes and operators (smooth blends with colour weights, limited and polar repetition), raymarching (sphere tracing, normals, soft shadows, ambient occlusion), a camera (look-at, pixel rays, orbit, dolly, dolly zoom, depth of field) |
| [`transitions/`](transitions) | `shotglass-kit/transitions` | `crossfade`, `fade`, `iris`, `dissolve`, `wipe` (moved from the engine, same parameters, same pixels) |
| [`fx/`](fx) | `shotglass-kit/fx` | passes for [layers](https://github.com/antonmarsden/shotglass#layers), used as `type = "fx/<name>"`: `grade` (exposure, lift/gain, contrast, saturation), `grain`, `dither`, `vignette`, `letterbox`, `place` (logo bug / picture-in-picture), `chroma_key` (keyed plates), and the bloom recipe `bright` + `blur` (needs shotglass 0.1.4; the bloom recipe 0.1.5) |
| [`blend/`](blend) | `shotglass-kit/blend` | blend modes for layers, used as `blend = "blend/<name>"`: `multiply`, `screen`, `overlay`, `hardlight`, `add`, `darken`, `lighten`, `difference`, `colordodge`, `colorburn`, `softlight`, with premultiplied alpha handled once in `modes.glsl` (needs shotglass 0.1.5) |
| [`text/`](text) | `shotglass-kit/text` | drawing [text blocks](https://github.com/antonmarsden/shotglass#text): placing a block by its centre, a corner or its baseline, sized by em in frame heights; ink that stays crisp at any scale, outlines, glows, drop shadows (needs shotglass 0.1.3) |
| [`quality/`](quality) | `shotglass-kit/quality` | metrics for [`shotglass quality`](https://github.com/antonmarsden/shotglass#quality-metrics), used from a film's `quality.toml`: picture metrics as `use = "quality/picture/<name>"` (`alias`, `banding`, `exposure`, `palette`, `shimmer`, `stepping`, `outlines`, `flatness`), sound metrics as `use = "quality/sound/<name>"` (`clicks`) (needs shotglass 0.1.6 at commit `efaac0f` or later, for `notMeasured()`) |
| [`sound/`](sound) | `shotglass-kit/sound` | for `mainSound`: ADSR and AR envelopes, MIDI note → hertz, scales and chords as note numbers, beat/bar steps from a tempo, exact at any length of film; instruments (plucked string, FM bell, electric piano, pad) and drums (kick, snare, hat); for `mainMix`: multi-tap delay, reverb, ducking (sidechain), a look-ahead limiter, stereo width, soft clip |

## Using it in a film

In the film's project file, `shotglass.toml` (next to `movie.toml`, or in a folder above
several films that share libraries):

```toml
# shotglass.toml
shotglass = "0.1"

[libraries]
kit = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "core" }
transitions = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "transitions" }
sound = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "sound" }
quality = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "quality" }
text = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "text" }
fx = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "fx" }
blend = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "blend" }
```

```glsl
#include <kit/noise.glsl>
#include <kit/color.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float clouds = kit_fbm(uv * 4.0 + vec2(iTime * 0.1, 0.0), 5);
    vec3 col = kit_palette(clouds, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.1, 0.2));
    fragColor = vec4(col * kit_vignette(uv, 0.3, 0.6), 1.0);
}
```

`shotglass fetch` (or the first `play`) downloads the kit and pins it in
`shotglass.lock` next to `shotglass.toml`; commit that file. The names on the left of
`[libraries]` are yours to choose: they're the prefix in `#include <kit/…>`.

### Noise patterns

`kit_cellular_noise` returns the two nearest feature distances for patterns such
as stone and scales. `kit_simplex_flow` returns rotating simplex noise and its
spatial gradient, with optional rectangular tiling.
`kit_curl_noise` in `<kit/noise.glsl>` rotates that gradient clockwise to give an
unnormalised, divergence-free 2D field. Scale it to taste for flow or UV warping.
Use an even positive y period for tiling, or zero on either axis to disable its
tiling. This example repeats over the unit UV square and loops every four seconds.

```glsl
vec2 velocity = kit_curl_noise(uv * vec2(6.0, 4.0), ivec2(6, 4),
                               6.28318531 * fract(iTime / 4.0));
```

The [simplex-flow shot](tests/film/scenes/simplex-flow.glsl) uses the field to
warp two side-by-side tiles and loops once per shot.

For blue-noise dithering, bind the CC0 tile as a data texture in a shot:

```toml
channels = [{ file = "<kit/textures/blue-noise-64.png>", filter = "nearest", srgb = false }]
```

Fetch one red-channel texel per pixel, wrapping the pixel coordinates by the tile
size. Pass `(255.0 * texel + 0.5) / 256.0` to `kit_dither` as the threshold.
The [blue-noise scene](tests/film/scenes/blue-noise.glsl) shows the same six-level
ramp with and without dithering. See [NOTICE](NOTICE) for source and licence details.

### Transitions

Until shotglass can name library transitions directly (`type = "transitions/iris"`),
use a one-line file in your film:

```glsl
// fx/iris.glsl
#include <transitions/iris.glsl>
```

```toml
transition = { type = "fx/iris.glsl", duration = 0.8, params = { center = [0.3, 0.6] } }
```

Every transition lists its parameters at the top of its file.

### Layers: fx and blend

A [layer](https://github.com/antonmarsden/shotglass#layers) is drawn over the shots. `fx/`
holds ready-made layer passes, named like a transition (`type = "fx/<name>"`); `blend/`
holds blend modes (`blend = "blend/<name>"`). Each file's header lists its channels,
uniforms and params. Animatable inputs are uniforms (`uniforms.uExposure = { keys = ... }`),
static options are `params`; anything a film leaves out has a default.

```toml
[[layer]]
id = "grade"
type = "fx/grade"                # exposure, lift and gain, contrast, saturation
channels = ["@input"]            # the picture below (filters read it on iChannel0)
params = { lift = [0.02, 0.0, 0.04] }
uniforms.uExposure = { keys = [[0, -2.0], [3, 0.0]] }

[[layer]]
id = "grain"
type = "fx/grain"
channels = ["@input"]
scale = 0.5                      # grain is one layer pixel: half resolution, twice as coarse
opacity = 0.6

[[layer]]
id = "bars"
type = "fx/letterbox"            # transparent bars, no input needed
uniforms.uAspect = 2.39

[[layer]]
id = "bug"
type = "fx/place"                # a logo bug: any [textures] image, or "@picture"
channels = ["logo"]
scale = 1
params = { anchor = [1.0, 1.0] }
uniforms.uPos = [0.96, 0.94]
uniforms.uSize = 0.1

[[layer]]
id = "leak"
scene = "layers/leak.glsl"       # your own layer, blended with a kit mode
blend = "blend/screen"
opacity = 0.7
```

`fx/vignette` and `fx/letterbox` write transparent pixels, so they need no channel and
work with any `blend`; `fx/grade` and `fx/grain` read `@input` and write an opaque
picture, so a layer's `opacity` is their strength. A pass assumes straight alpha from its
channel, which is what `[textures]` images and `@picture` give.

**Chroma key** uses a plate on `iChannel0`. Bind a `[textures]` image or, with
shotglass 0.1.6, an image sequence. Leave the texture's `srgb` option at its default
(`false`) to sample display RGB. The pass fits the plate to the frame and multiplies
its straight alpha by the matte. The shot underneath supplies the background.

```toml
[textures]
plate = "renders/plate_####.png"

[[layer]]
id = "keyed-plate"
type = "fx/chroma_key"
channels = ["plate"]
uniforms.uKeyColor = [0.08, 0.84, 0.13]
uniforms.uThreshold = 0.12
uniforms.uSoftness = 0.30
uniforms.uDespill = 1.0
```

Sample `uKeyColor` from the screen in display RGB (default pure green). Raise
`uThreshold` to clear more of the screen. `uSoftness` sets the extra chroma distance
to full coverage, with zero giving a hard edge. `uDespill` controls removal of
key-coloured spill from 0 to 1 and leaves coverage unchanged.

**Dither** needs the core library, named `kit` in this example. Add the pass
after colour grading and glow, at full layer resolution.

```toml
[[layer]]
id = "dither"
type = "fx/dither"
scale = 1
channels = ["@input", { file = "<kit/textures/blue-noise-64.png>", filter = "nearest", srgb = false }]
params = { ditherLevels = 64 }   # output levels per RGB channel, 2..256 (default 64)
```

The pass spreads the quantization steps of gradients and glows into a fixed
pixel-space pattern. A static picture at the same size keeps the same pattern
across frames. Smaller level counts make the texture easier to see. Since
Shotglass supplies an 8-bit `@input`, 256 levels leave that input unchanged and
the pass cannot recover detail lost in earlier rounding. The encoder may change
how much of the pattern survives. Compare plain and dithered 16-level rounding
in [the layer test film](tests/layers/movie.toml).

**Blend modes** (`blend/<name>`): `multiply`, `screen`, `overlay`, `hardlight`, `add`
(linear dodge), `darken`, `lighten`, `difference`, `colordodge`, `colorburn`,
`softlight`. Every one takes the layer premultiplied, as the engine gives it, undoes
that to get the layer's own colour, applies the mode there, and mixes the result over the
picture by the layer's coverage x opacity: so a half-transparent layer is half a
multiply, and nothing under a fully transparent pixel changes. The maths is in
`blend/modes.glsl` (`kit_blend_multiply(cb, cs)` and so on, `kit_blend_composite` for the
mixing), so a film-local blend pass can reuse it:

```glsl
// fx/my_blend.glsl: multiply the dark half of the layer, screen the light half
#include <blend/modes.glsl>
vec4 blend(vec2 uv) {
    vec4 b = getBase(uv), l = getLayer(uv);
    vec3 cs = kit_blend_source(l);
    return kit_blend_composite(b, l, mix(kit_blend_multiply(b.rgb, cs), kit_blend_screen(b.rgb, cs), step(0.5, cs.g)));
}
```

**Bloom** (needs shotglass 0.1.5) is three layers: a bright pass drawn at `opacity = 0`
(a hidden helper), a blur across that reads it with `@bright`, and a blur down that
reads that and is screened (or added, for a hotter glow) over the picture. Run them at
`scale = 0.5`: a quarter of the cost, and the blur is soft anyway.

```toml
[[layer]]
id = "bright"
type = "fx/bright"
channels = ["@input"]
scale = 0.5
opacity = 0
uniforms.uThreshold = 0.7

[[layer]]
id = "across"
type = "fx/blur"
channels = ["@bright"]
scale = 0.5
opacity = 0
params = { direction = [1.0, 0.0] }
uniforms.uRadius = 0.03

[[layer]]
id = "bloom"
type = "fx/blur"
channels = ["@across"]
scale = 0.5
opacity = 0.8
blend = "blend/screen"           # or "blend/add"
params = { direction = [0.0, 1.0] }
uniforms.uRadius = 0.03
uniforms.uGain = 2.0
```

(`fx` and `blend` are the names this snippet gives the libraries; the film-local `fx/iris.glsl` of
the Transitions section is a file path, which ends in `.glsl`, so the two don't clash.)

A layer reads another only if it comes later in `movie.toml` and the ids are plain
identifiers (`bright_pass`, not `bright-pass`); give the helper layers the same `from`
and `to`, because `@<id>` is black while that layer isn't active.

### Text

shotglass sets the words of a `[texts]` block into a texture (coverage, and a signed
distance field for crisp edges) and binds it to an `iChannel`; `text/block.glsl` draws it.
Needs `shotglass = "0.1.3"` in `shotglass.toml`.

The kit ships no fonts: any Google Fonts family is a library of its own (see shotglass's
README, "Getting fonts"). `shotglass fonts add` declares it, fetches it and pins it:

```sh
shotglass fonts add "Bungee" "Inter"
```

```toml
# shotglass.toml (written by fonts add)
[libraries]
bungee = { google = "Bungee" }
inter = { google = "Inter" }
```

```toml
# movie.toml (fonts add writes the [fonts] entries; rename them or add variations)
[fonts]
title = "<bungee/Bungee-Regular.ttf>"
body = { file = "<inter/Inter[opsz,wght].ttf>", variations = { wght = 450 } }

[texts]
title = { text = "Big Shadow", font = "title", size = 128, sdf_spread = 16 }
tagline = { text = "a tiny mouse and a lot of wall", font = "body", size = 64 }

[[shot]]
id = "titlecard"
scene = "scenes/title.glsl"
duration = 4.0
channels = ["title", "tagline"]
```

```glsl
#include <text/block.glsl>

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec3 col = vec3(0.05, 0.05, 0.1);
    // Centred at (0.5, 0.55) of the frame, an em 0.2 frame heights tall.
    kit_text_box t = kit_text_place(iChannelResolution[0], iChannelMeta[0], fragCoord, iResolution.xy, vec2(0.5, 0.55), 0.2);
    col = mix(col, vec3(0.0), 0.6 * kit_text_shadow(iChannel0, t, vec2(0.04, -0.05), 0.1));
    col += vec3(1.0, 0.5, 0.2) * 0.4 * kit_text_glow(iChannel0, t, 0.15);
    col = mix(col, vec3(0.1), kit_text_outline(iChannel0, t, 0.05));
    col = mix(col, vec3(1.0, 0.9, 0.7), kit_text_edge(iChannel0, t, 0.0));
    // The tagline's first baseline at 0.25 of the frame height, centred.
    kit_text_box s = kit_text_place_baseline(iChannelResolution[1], iChannelMeta[1], fragCoord, iResolution.xy, vec2(0.5, 0.25), 0.05, 0.5);
    col = mix(col, vec3(0.9), kit_text_coverage(iChannel1, s));
    fragColor = vec4(col, 1.0);
}
```

Sizes are in ems: `em` in `kit_text_place*` is the font size as a fraction of the frame
height, so blocks rasterised at different `size`s line up and match (`size` only sets
the quality: rasterise as large as the text gets on screen). Outline widths, glow radii,
shadow offsets and softness are ems too, up to `kit_text_reach(meta)` (the block's
`sdf_spread` over its `size`, 0.125 em by default: raise `sdf_spread` for more).
`kit_text_box` also gives `local` (0..1 across the text) and `p` (ems from the first
baseline) for gradients, wipes and per-line effects. The helpers assume the block's
default `vflip = true` and handle the flip themselves.

### Sound

The `sound` library is for music and shot sounds. Notes are MIDI numbers until the
last moment, and the tempo helpers give each sample its step and the exact time since
that step began, which is what envelopes and oscillators want:

```glsl
#include <sound/envelope.glsl>
#include <sound/note.glsl>
#include <sound/tempo.glsl>

vec2 mainSound(int samp, float time) {
    int rate = int(iSampleRate);
    int step = kit_beat_step(samp, rate, 120, 4);        // sixteenth notes at 120 bpm
    float since = kit_beat_since(samp, rate, 120, 4);    // seconds into this one
    int bar = kit_beat_bar(step, 16);
    int note = kit_scale_chord(int[4](0, 5, 3, 4)[bar % 4], step % 4, 60, 0xAB5);  // I vi IV V, arpeggiated
    float hz = kit_note_hz(note);
    float v = sin(6.28318531 * fract(hz * since)) * kit_env_ar(since, 0.003, 0.12);
    return vec2(0.2 * v);
}
```

`sound/instrument.glsl` and `sound/drum.glsl` are ready-made voices, each one function
of the time since the note began, its frequency and a few parameters, returning a
level around +-1. A note fades in from 0 and ends in silence at a time its header
gives, so keep calling it after the next note starts and it never clicks:

```glsl
#include <sound/instrument.glsl>   // kit_inst_pluck, kit_inst_bell, kit_inst_epiano, kit_inst_pad
#include <sound/drum.glsl>         // kit_drum_kick, kit_drum_snare, kit_drum_hat

// inside mainSound, with step and since from kit_beat_step / kit_beat_since (eighths)
float v = kit_inst_pluck(since, hz, 1.0, 0.6)
        + kit_inst_pluck(since + 0.25, prev_hz, 1.0, 0.6)   // the previous note's tail
        + kit_drum_kick(since, 50.0, 0.4) * float(step % 4 == 0)
        + kit_drum_hat(since, 2000.0, 0.06);
```

`sound/mix.glsl` is for the film's mix (`[sound] mix`): effects that read the music and
shot-sound buses at other samples. They have no feedback, so every sample is computed
on its own and nothing can run away; keep every delay, reverb size and release under the
film's `mix_lookback` (default 1 s; reads further back return silence). It includes
`sound/master.glsl` (width, ducking gain, soft clip), which works in any sound shader.

```glsl
#include <sound/mix.glsl>

vec2 mainMix(int samp, float time) {
    int rate = int(iSampleRate);
    vec2 m = music(samp) * kit_mix_duck(samp, rate, 0.12, 0.35, 0.7);    // dips under the effects
    m += 0.35 * kit_mix_delay(kit_bus_music, samp, rate, 0.31, 2, 0.5, 1.0);   // ping-pong echo
    vec2 fx = sfx(samp) + 0.3 * kit_mix_reverb(kit_bus_sfx, samp, rate, 0.13, 0.1);   // a room
    vec2 o = kit_width(m, 1.3) + fx;
    o *= kit_mix_limit(kit_bus_all, samp, rate, 1.0, 0.85);              // look-ahead limiter
    return kit_soft_clip(o, 0.9);
}
```

### Quality metrics

`shotglass quality <film>` renders sample frames, measures them with the metrics in the
film's `quality.toml`, writes a report and heatmaps, and fails when a metric is outside
its limits (shotglass README, "Quality metrics"). The engine provides the measuring; the
metrics are here, versioned like everything else, so a film's numbers only move when it
moves to a new kit release. Picture metrics (`[[metric]]`) are in `quality/picture/`,
sound metrics (`[[sound.metric]]`) in `quality/sound/`. Each file's header gives what it measures, its units, its
params and typical limits.

| metric | measures | per-pixel (per-sample) measure | judge |
|---|---|---|---|
| `picture/alias` | spatial aliasing: jaggies, moiré | largest channel difference from `@reference`, 0..1 | `mean` |
| `picture/banding` | gradient stepping | 1 on a 1-2 level step between flat runs | `mean` |
| `picture/exposure` | clipped highlights, crushed blacks | 1 where the brightest channel is at full scale (or at 0) | `mean` |
| `picture/palette` | conformance to declared colours (`PALETTE`) | ΔE (CIE76) to the nearest palette colour | `over` a ΔE `threshold` |
| `picture/shimmer` | crawl, sparkle, flicker | largest channel of frame − mean of `@prev` and `@next` | `mean` |
| `picture/stepping` | holds between steps on twos/threes (`STEP`) | change from `@prev` on frames between steps (step frames not measured) | `max` |
| `picture/outlines` | line width in screen space (`WIDTH`) | ink thickness − WIDTH, in pixels (ink pixels only) | `over` or `p95` |
| `picture/flatness` | toon shading: no soft gradients | 1 in a steady ramp of 0.75-16 levels/pixel | `mean` |
| `sound/clicks` (`[[sound.metric]]`) | discontinuities, cuts mid-wave | jump in slope over its local RMS, a ratio | `max` |

```toml
# quality.toml, next to movie.toml
count = 8
reference = 4

[[metric]]
use = "quality/picture/alias"
mean = { max = 0.01 }

[[metric]]
use = "quality/picture/palette"
params = { PALETTE = ["#1d2b53", "#ff004d", "#fff1e8"] }
range = [0, 50]
threshold = 5                  # ΔE
over = { max = 0.03 }          # at most 3% of pixels (antialiased edges) off the palette

[sound]
true_peak = { max = -1 }       # dBTP, measured by the engine

[[sound.metric]]
use = "quality/sound/clicks"
range = [0, 100]
threshold = 20
max = { max = 20 }
```

Start with the header's typical limits, run `shotglass quality`, look at the heatmaps
(written to `quality-out/`),
then let `shotglass quality --tighten` ratchet them. Measured numbers depend on the
frame size and on the renderer (a little), so tighten with a margin.

### 2D signed-distance coverage

Include `core/sdf_coverage.glsl` in a picture shader to convert a signed distance
(negative inside) to coverage in 0..1. `kit_sd_fill` covers the inside of the shape.
`kit_sd_outline` covers a band centred on the zero contour. Its width is the full
width in raster pixels, including fractional widths.

```glsl
#include <kit/sdf.glsl>
#include <kit/sdf_coverage.glsl>

// In mainImage:
vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
float d = kit_sd_circle(p, 0.2);
float fill = kit_sd_fill(d);
float ink = kit_sd_outline(d, 0.75);
```

Call both helpers before fragment-dependent branches. They use screen derivatives to
estimate how much of a square pixel the locally straight edge covers. Very tight
curves and cusps can differ from supersampling. For a reference rendered at a higher
resolution and then downsampled, multiply the outline width by the render scale.
The `sdf-coverage` shot in `tests/film` shows the same moving 0.75 px ring and
outlined disc with point sampling (left), derivative coverage (middle), and 16×16
supersampling within each output pixel (right).

### Raymarching

GLSL can't pass a function as a parameter, so `core/raymarch.glsl` calls one that your
shader defines: `float kit_scene(vec3 p)`, the distance to your scene.

```glsl
#include <kit/sdf.glsl>
#include <kit/raymarch.glsl>

float kit_scene(vec3 p) {
    return min(kit_sd_plane(p, vec3(0.0, 1.0, 0.0), 0.0), kit_sd_sphere(p - vec3(0.0, 1.0, 0.0), 1.0));
}

// in mainImage, with a camera ray ro, rd:
float t = kit_raymarch(ro, rd, 128, 0.001, 20.0);    // -1.0 on a miss
if (t >= 0.0) {
    vec3 p = ro + rd * t;
    vec3 n = kit_normal(p, 0.001);
    float light = max(dot(n, sun), 0.0) * kit_soft_shadow(p + n * 0.002, sun, 0.01, 10.0, 8.0);
    float ao = kit_ao(p, n, 0.3);
}
```

`core/sdf_ops.glsl` adds operators for building scenes: `kit_op_union` on
(distance, material) pairs, `kit_op_smin_blend` (a smooth union that says how to mix
the two colours), `kit_op_ssubtract`, `kit_op_repeat_limited`, `kit_op_repeat_id`
(which copy you're in, for `kit_hash`) and `kit_op_repeat_polar`.

### Camera

`core/camera.glsl` gives the `ro, rd` above, placed by numbers `movie.toml` can keyframe:

```toml
uniforms.uOrbit = { keys = [[0, [0.0, 0.3]], [6, [1.2, 0.5]]], ease = "inout" }   # yaw, pitch
uniforms.uDist  = { keys = [[0, 6.0], [6, 3.5]] }
```

```glsl
#include <kit/camera.glsl>

vec3 ta = vec3(0.0, 1.0, 0.0);
vec3 ro = kit_cam_orbit(ta, uOrbit, uDist);              // or kit_cam_dolly(ro, ta, d)
mat3 cam = kit_cam_look_at(ro, ta, 0.0);                 // last argument: roll
vec3 rd = kit_cam_ray(cam, fragCoord, iResolution.xy, 0.8);   // vertical fov, radians
```

`kit_cam_dolly_zoom` gives the field of view for a "vertigo" shot, and `kit_cam_dof`
jitters a ray across the lens for depth of field (average a few rays per pixel).

## What every part promises

In short (the full rules, with units, precision, sound and versioning, are in
[CONVENTIONS.md](CONVENTIONS.md)):

- **A header contract on every public function:** what it does, parameters with units
  and ranges, cost, and an example. You (or an AI) shouldn't need to read the body.
- **Names:** public functions start with `kit_`, internals with `kit_private_`. A library you
  add next to the kit won't clash with it.
- **Portable:** everything compiles as GLSL 3.30 core and GLSL ES 3.00 (WebGL 2),
  checked by a reference compiler (glslang) in CI, not just by one GPU's driver.
- **Deterministic:** the same inputs give the same pixels on the same CPU and GPU, as in
  shotglass itself. Other GPUs and drivers can differ slightly (built-ins like `sin()`
  round differently), so the kit keeps those differences small rather than chasing
  bit-identical output everywhere.
- **No global state:** include any file in any order; each file is included once.

## Working on the kit

The test film in [`tests/film`](tests/film) includes every picture and core file and
uses every transition; [`tests/sound`](tests/sound) and
[`tests/instruments`](tests/instruments) and [`tests/mix`](tests/mix) are the sound
library's: the first's music calls every envelope, note and tempo function, the second
plays a phrase on each instrument and drum, the third's mix turns on one mix effect a
bar; [`tests/layers`](tests/layers) shows every blend mode over one picture and then each fx pass;
[`tests/text`](tests/text) draws a title card and a lower third with `text/` in three
Google Fonts families (declared in the kit's `shotglass.toml`, pinned in its
`shotglass.lock`). They use the libraries in this checkout, declared once in the
[`shotglass.toml`](shotglass.toml) at the kit's root (the test films' project), so they
never download anything:

```sh
shotglass check tests/film --web --no-gpu   # strict GLSL: 3.30 core and ES 3.00
shotglass check tests/layers --web --no-gpu # fx/ and blend/ (strict too)
shotglass strip tests/layers --count 8 --out strip.png   # look at the blend modes and fx
shotglass check tests/film                  # compile on your GPU, render, time
shotglass play tests/film                   # watch it, with live reload
shotglass play tests/sound                  # listen to the sound library
shotglass play tests/instruments            # and to its instruments
shotglass play tests/mix                    # and its mix effects
shotglass play tests/text                   # the text library
shotglass test tests/unit                   # unit and property tests and quality metric tests, on your GPU
```

[`tests/unit`](tests/unit) holds unit and property tests of what each function's header
promises (`core/ease.test.glsl` for `core/ease.glsl`, and so on), run by
[`shotglass test`](https://github.com/antonmarsden/shotglass#testing-glsl) with the
engine's `expect*` assertions. Where the test films show that something looks and sounds
right, these pin the contract: exact endpoints, ranges, identities (sRGB round trip, an
octave doubles), hashes bit for bit against CPU-computed values, SDFs that never change
faster than the point moves, notes silent from their documented end.
[`tests/unit/quality`](tests/unit/quality) also holds the `quality/` metrics' must-pass
and must-fail cases (`picture.test.toml`, `sound.test.toml`: each metric run on small
input shaders in `fixtures/`, judged by limits like a film's `quality.toml`), so a metric
that stops seeing what it measures turns CI red.

### Audio references

CI renders the soundtracks of `tests/sound`, `tests/instruments` and `tests/mix` on Mesa
at 8 kHz and compares them with [`tests/golden/sound.wav`, `instruments.wav` and
`mix.wav`](tests/golden), failing when any 50 ms window differs by more
than `shotglass wav --compare`'s default tolerance (which real GPUs stay inside):

```sh
xvfb-run -a shotglass wav tests/sound --rate 8000 --out sound.wav --compare tests/golden/sound.wav
xvfb-run -a shotglass wav tests/instruments --rate 8000 --out instruments.wav --compare tests/golden/instruments.wav
xvfb-run -a shotglass wav tests/mix --rate 8000 --out mix.wav --compare tests/golden/mix.wav
```

A change that should keep the sound the same must keep passing. If the sound is
meant to change (new or changed code in `sound/` or in the test music), add
`--bless` to write the new reference, listen to it, and commit it with the change.
Bless on Linux with Mesa (`xvfb-run -a` with llvmpipe), like CI, when you can.

To try a working copy in your own film without changing its `shotglass.toml`:

```sh
SHOTGLASS_LIB_KIT=../shotglass-kit/core shotglass play my-film
SHOTGLASS_LIB_FX=../shotglass-kit/fx SHOTGLASS_LIB_BLEND=../shotglass-kit/blend shotglass play my-film
```

CI runs the strict check, renders the films on Mesa, compares the test, animation, text and layers films with their
golden pictures and the audio references, checks that every transition starts exactly on
the old shot and ends exactly on the new one, and fails if any library file isn't included by a test film or a public function
isn't called by one. A daily canary runs the same checks against shotglass `main`
([CONTRIBUTING.md](CONTRIBUTING.md#canary)). New code
follows [CONVENTIONS.md](CONVENTIONS.md); see also [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence and credit

Licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT), at your
option, including for commercial films. Redistributing the kit's source means keeping
its copyright notice ([NOTICE](NOTICE)).

**Not required, but appreciated:** if the kit helped make your film, a line in the
credits helps others find it:

> Made with shotglass and shotglass-kit

`shotglass licenses` (coming) lists every library and licence a film uses.
