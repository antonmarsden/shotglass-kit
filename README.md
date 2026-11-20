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

Planned (shotglass issue #4): raymarching and camera helpers in `core/`, and sound:
envelopes, notes and scales, instruments, and mix effects.

## Using it in a film

```toml
# movie.toml
shotglass = "0.1"

[libraries]
kit = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "core" }
transitions = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "transitions" }
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

## What every part promises

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

The test film in [`tests/film`](tests/film) includes every file and uses every
transition. Its `movie.local.toml` points at this checkout, so it never downloads
anything:

```sh
shotglass check tests/film --web --no-gpu   # strict GLSL: 3.30 core and ES 3.00
shotglass check tests/film                  # compile on your GPU, render, time
shotglass play tests/film                   # watch it, with live reload
```

To try a working copy in your own film without changing its `movie.toml`:

```sh
SHOTGLASS_LIB_KIT=../shotglass-kit/core shotglass play my-film
```

CI runs the strict check, renders the film on Mesa, and fails if any library file
isn't included by the test film. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Licence and credit

Licensed under either of [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT), at your
option, including for commercial films. Redistributing the kit's source means keeping
its copyright notice ([NOTICE](NOTICE)).

**Not required, but appreciated:** if the kit helped make your film, a line in the
credits helps others find it:

> Made with shotglass and shotglass-kit

`shotglass licenses` (coming) lists every library and licence a film uses.
