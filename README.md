# shotglass-kit

Versioned GLSL libraries for [shotglass](https://github.com/antonmarsden/shotglass)
films. Films are assembled from tested parts instead of written from scratch, and
each film pins the exact kit version it was made with, so a new kit release never
changes a finished film.

Each folder is a separate library that a film picks (and pins) on its own:

| folder | canonical name | what's in it |
|---|---|---|
| [`core/`](core) | `shotglass-kit/core` | eases, deterministic hashes and noise, colour (tonemapping, sRGB, palettes, vignette, grain), signed distance shapes |
| [`transitions/`](transitions) | `shotglass-kit/transitions` | `crossfade`, `fade`, `iris`, `dissolve`, `wipe` (moved from the engine, same parameters, same pixels) |
| [`sound/`](sound) | `shotglass-kit/sound` | for `mainSound`: ADSR and AR envelopes, MIDI note → hertz, scales and chords as note numbers, beat/bar steps from a tempo, exact at any length of film |

Planned (shotglass issue #4): raymarching and camera helpers in `core/`; instruments
and mix effects in `sound/`.

## Using it in a film

```toml
# movie.toml
shotglass = "0.1"

[libraries]
kit = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "core" }
transitions = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "transitions" }
sound = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "sound" }
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
`shotglass.lock`; commit that file with the film. The names on the left of
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
uses every transition; [`tests/sound`](tests/sound) is the sound library's, with music
that calls every function in `sound/`. Their `movie.local.toml` points at this
checkout, so they never download anything:

```sh
shotglass check tests/film --web --no-gpu   # strict GLSL: 3.30 core and ES 3.00
shotglass check tests/film                  # compile on your GPU, render, time
shotglass play tests/film                   # watch it, with live reload
shotglass play tests/sound                  # listen to the sound library
```

### Audio references

CI renders `tests/sound`'s soundtrack on Mesa at 8 kHz and compares it with
[`tests/golden/sound.wav`](tests/golden), failing when any 50 ms window differs by more
than `shotglass wav --compare`'s default tolerance (which real GPUs stay inside):

```sh
xvfb-run -a shotglass wav tests/sound --rate 8000 --out sound.wav --compare tests/golden/sound.wav
```

A change that should keep the sound the same must keep passing. If the sound is
meant to change (new or changed code in `sound/` or in the test music), add
`--bless` to write the new reference, listen to it, and commit it with the change.
Bless on Linux with Mesa (`xvfb-run -a` with llvmpipe), like CI, when you can.

To try a working copy in your own film without changing its `movie.toml`:

```sh
SHOTGLASS_LIB_KIT=../shotglass-kit/core shotglass play my-film
```

CI runs the strict check, renders the films on Mesa, compares the audio references,
and fails if any library file isn't included by a test film or a public function
isn't called by one. New code
follows [CONVENTIONS.md](CONVENTIONS.md); see also [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence and credit

Licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT), at your
option, including for commercial films. Redistributing the kit's source means keeping
its copyright notice ([NOTICE](NOTICE)).

**Not required, but appreciated:** if the kit helped make your film, a line in the
credits helps others find it:

> Made with shotglass and shotglass-kit

`shotglass licenses` (coming) lists every library and licence a film uses.
