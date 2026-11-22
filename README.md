# shotglass-kit

Versioned GLSL libraries for [shotglass](https://github.com/antonmarsden/shotglass)
films. Films are assembled from tested parts instead of written from scratch, and
each film pins the exact kit version it was made with, so a new kit release never
changes a finished film.

Each folder is a separate library that a film picks (and pins) on its own:

| folder | canonical name | what's in it |
|---|---|---|
| [`core/`](core) | `shotglass-kit/core` | eases, cartoon animation (back, elastic and bounce eases, squash and stretch, anticipation and settle, held keyed poses, animating on twos), deterministic hashes and noise, colour (tonemapping, sRGB, palettes, vignette, grain), signed distance shapes and operators (smooth blends with colour weights, limited and polar repetition), raymarching (sphere tracing, normals, soft shadows, ambient occlusion), a camera (look-at, pixel rays, orbit, dolly, dolly zoom, depth of field) |
| [`transitions/`](transitions) | `shotglass-kit/transitions` | `crossfade`, `fade`, `iris`, `dissolve`, `wipe` (moved from the engine, same parameters, same pixels) |
| [`text/`](text) | `shotglass-kit/text` | drawing [text blocks](https://github.com/antonmarsden/shotglass#text): placing a block by its centre, a corner or its baseline, sized by em in frame heights; ink that stays crisp at any scale, outlines, glows, drop shadows (needs shotglass 0.1.3) |
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
text = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "text" }
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

### Text

shotglass sets the words of a `[texts]` block into a texture (coverage, and a signed
distance field for crisp edges) and binds it to an `iChannel`; `text/block.glsl` draws it.
Needs `shotglass = "0.1.3"` in `shotglass.toml`.

The kit ships no fonts: fetch any family from Google Fonts into the film, with its
licence, and use it from the film's folder (see shotglass's README, "Getting fonts"):

```sh
shotglass fonts add "Bungee" "Inter"
```

```toml
# movie.toml (fonts add writes the [fonts] entries; rename or add variations as you like)
[fonts]
title = { file = "fonts/bungee/Bungee-Regular.ttf", licence = "OFL-1.1" }
body = { file = "fonts/inter/Inter-Variable.ttf", variations = { wght = 450 }, licence = "OFL-1.1" }

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
- **Names:** public functions start with `kit_`, internals with `kit__`. A library you
  add next to the kit won't clash with it.
- **Portable:** everything compiles as GLSL 3.30 core and GLSL ES 3.00 (WebGL 2),
  checked by a reference compiler (glslang) in CI, not just by one GPU's driver.
- **Deterministic:** the same inputs give the same pixels. Hashes and noise use integer
  arithmetic, so they match on every GPU (`sin()`-based hashes don't).
- **No global state:** include any file in any order; each file is included once.

## Working on the kit

The test film in [`tests/film`](tests/film) includes every picture and core file and
uses every transition; [`tests/sound`](tests/sound) and
[`tests/instruments`](tests/instruments) and [`tests/mix`](tests/mix) are the sound
library's: the first's music calls every envelope, note and tempo function, the second
plays a phrase on each instrument and drum, the third's mix turns on one mix effect a
bar; [`tests/text`](tests/text) draws a title card and a lower third with `text/` and the
fonts in its own `fonts/` folder. They use the libraries in this checkout, declared once in the
[`shotglass.toml`](shotglass.toml) at the kit's root (the test films' project), so they
never download anything:

```sh
shotglass check tests/film --web --no-gpu   # strict GLSL: 3.30 core and ES 3.00
shotglass check tests/film                  # compile on your GPU, render, time
shotglass play tests/film                   # watch it, with live reload
shotglass play tests/sound                  # listen to the sound library
shotglass play tests/instruments            # and to its instruments
shotglass play tests/mix                    # and its mix effects
shotglass play tests/text                   # the text library
shotglass test tests/unit                   # unit and property tests, on your GPU
```

[`tests/unit`](tests/unit) holds unit and property tests of what each function's header
promises (`core/ease.test.glsl` for `core/ease.glsl`, and so on), run by
[`shotglass test`](https://github.com/antonmarsden/shotglass#testing-glsl) with the
engine's `expect*` assertions. Where the test films show that something looks and sounds
right, these pin the contract: exact endpoints, ranges, identities (sRGB round trip, an
octave doubles), hashes bit for bit against CPU-computed values, SDFs that never change
faster than the point moves, notes silent from their documented end.

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
```

CI runs the strict check, renders the films on Mesa, compares the test, animation and text films with their
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
