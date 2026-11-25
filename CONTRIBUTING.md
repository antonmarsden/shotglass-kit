# Contributing

Code in the kit follows [CONVENTIONS.md](CONVENTIONS.md): names, units, determinism,
precision, picture vs sound, tests, versioning and doc comments. This file is the short
version plus licensing and releases; where they differ, CONVENTIONS.md wins.

## Licensing

Contributions are accepted under the project's licence: by opening a pull request you
agree that your contribution is licensed under both Apache-2.0 and MIT, like the rest
of the kit (inbound = outbound).

Only contribute code you wrote or that you know is compatible. In particular, much
shader code online (Shadertoy's default, for one) is CC BY-NC-SA, **non-commercial**,
and can't come into the kit. A permissively licensed snippet (MIT, Apache-2.0,
public domain, CC0) is fine if you name its source and licence in the file.

## Adding a function

- **Prefix** public functions `kit_` and helpers `kit_private_`.
- **Header contract** above every public function: what it does, each parameter with
  units and range, what it returns, cost, and a one-line example. Copy the style of
  `core/noise.glsl`.
- **Portable GLSL:** GLSL 3.30 core features only, and valid GLSL ES 3.00: float
  literals (`1.0`, not `1`), `U` on unsigned literals, no implicit int→float.
  `shotglass check tests/film --web --no-gpu` checks both dialects with glslang.
  CI also runs `.github/check-webgl.cjs` to catch reserved identifiers glslang
  accepts and compile the simplex-flow scene with Chromium's WebGL 2 compiler.
- **Deterministic:** no `sin()` hashes or other GPU-dependent tricks in new code. Use
  `kit_hash` from `core/noise.glsl`.
- **No global state:** no global variables, no `#define`s that leak names (a
  transition's parameter `#define`s are the exception: they're its interface).
- **Use it in a test film** (`tests/film`, or `tests/animation` for `core/animate.glsl`; `tests/sound`, `tests/instruments` or `tests/mix` for the `sound/` library; `tests/text` for `text/`; `tests/layers` for `fx/` and `blend/`; `tests/unit/quality/*.test.toml` for `quality/`, see "Adding a quality metric"): CI
  fails if a library file isn't included or a public function isn't called. A sound-safe
  file (`// sound: yes`) is also included by a test film's `music.glsl`, so it's checked
  as a sound shader too; a mix-only file (`// sound: mix only`, it calls `music()` /
  `sfx()`) by a test film's `mix.glsl`.
- **Unit-test its contract** in `tests/unit/<library>/<file>.test.glsl` (`shotglass
  test tests/unit`, run by CI on Mesa): the header's promises are the spec. Endpoints and
  known values, the documented range over the whole input range (a property test:
  `void test_x(float t)` sweeps `t` over 0..1), identities and inverses, and silence or
  zero where the header says so. Compare floats with `expect_near` / `expect_rel` and a
  tolerance you can justify, `expect_eq` only where the result is exact on every GPU
  (integer maths, exact literals, clamps). A test that fails because the code breaks its
  header is a bug in the code or the header: fix one of them, don't widen the test.
- **Picture changes:** CI compares frames of `tests/film` with `tests/golden/film.png`,
  of `tests/animation` with `tests/golden/animation.png`, and of `tests/text` with
  `tests/golden/text.png`.
  If a change is meant to alter what the test film looks like, re-bless it ("Golden
  picture" below), look at it, and commit it with the change.
- **Sound changes:** CI compares the soundtracks of `tests/sound`, `tests/instruments` and
  `tests/mix` with `tests/golden/sound.wav`, `instruments.wav` and `mix.wav`.
  If the sound is meant to change, re-bless the reference (README, "Audio references"),
  listen to it, and commit it with the change.

## Fonts

The kit ships no fonts. A Google Fonts family is a library of its own: films declare it
in their project (`name = { google = "Family" }`) and name its files in `[fonts]`
(`"<name/File.ttf>"`); shotglass fetches it and pins it in `shotglass.lock` like any
library. `shotglass fonts add "<Family>"` writes both (shotglass README, "Getting fonts").
The test films do the same: `tests/text`'s families are declared in the kit's
`shotglass.toml` and pinned in its `shotglass.lock`, so CI fetches the same files every
time. CI fails if a font file is committed.

## Adding a transition

A transition defines `vec4 transition(vec2 uv)` using `getFromColor(uv)`,
`getToColor(uv)`, `progress` (0..1) and `ratio` (width / height). Parameters are
`#define`s with `#ifndef` defaults, documented at the top. It must show exactly the
old shot at `progress = 0` and exactly the new one at `progress = 1`.

CI checks this for every transition in `tests/transitions/movie.toml`, with zero
tolerance ([`.github/transition-endpoints.sh`](.github/transition-endpoints.sh)): the
first instant of each transition must equal the old shot pixel for pixel, and the last
instant before the cut the new one. Add a shot there for a new transition, and one per
parameter that changes how it starts or ends (`closing` for the iris, say). Run it
locally with `xvfb-run -a .github/transition-endpoints.sh` (plain on Windows/macOS, in
Git Bash there); on a failure, `transition-endpoints/endpoints.diff.png` marks the wrong
pixels in magenta, one row per transition, start on the left, end on the right.

## Adding an fx pass or a blend mode

An `fx/` pass is a layer shader: `mainImage` writes straight alpha, reading the picture
below on `iChannel0` when the film gives it `channels = ["@input"]`. Put the maths in a
`kit_fx_` function in `fx/ops.glsl` (unit tests can't include a file that reads
`iChannel0`); the pass file is its header, `#include "ops.glsl"`, defaults, and a short
`mainImage`. Animatable inputs are uniforms (`uAmount`) with `#ifndef SG_HAS_<name>`
defaults; static options are `#define` params with `#ifndef` defaults, named so they
don't clash with anything in `ops.glsl` (CONVENTIONS.md §1).

A blend mode is a function `kit_blend_<mode>(cb, cs)` in `blend/modes.glsl` on straight
colour, plus a pass `blend/<mode>.glsl`: `getBase`, `getLayer`, `kit_blend_source`,
`kit_blend_composite`, as the existing ones. Don't unpremultiply or mix anywhere else.

Add a layer for it to `tests/layers/movie.toml` (a second of film, in the order the
header comment lists), unit-test its function in `tests/unit/fx` or `tests/unit/blend`,
run `shotglass check tests/layers --web --no-gpu`, look at the strip, and re-bless
`tests/golden/layers.png` (below). A new folder starts at version 0.1.0 in its
`library.toml`; `requires_shotglass` is the engine release that has the layer feature it
uses.

## Adding a quality metric

A picture metric (`quality/picture/<name>.glsl`, used as `quality/picture/<name>`) defines `void mainMetric(out vec4 value, in
vec2 fragCoord)`: `value.a` the per-pixel measure, `value.rgb` its heatmap colour
(`kit_q_heat`). It reads `getFrame`, `getReference`, `getPrev`, `getNext` (shotglass
README, "Quality metrics"). A metric that applies to some pixels only writes
`value.a = notMeasured()` elsewhere, so its mean and percentiles cover the measured
ones. A sound metric (`quality/sound/<name>.glsl`) defines `void mainSoundMetric(out float
value, in int samp)` reading `getSound`, and says `// sound: metric only`. Params are
`#define`s with `#ifndef` defaults, in capitals so they can't rewrite anything in
`ops.glsl` (numbers arrive as floats). The header says what it measures, the units,
each param, typical limits, the variants it reads and its cost.

Put the maths in a `kit_q_` function in `quality/ops.glsl` and unit-test it in
`tests/unit/quality/ops.test.glsl`: the metric files (which include it as `"../ops.glsl"`) read the engine's samplers, which
unit tests don't have. Test what it must catch **and** what it must let through.

Every metric has at least one must-pass and one must-fail case in
`tests/unit/quality/picture.test.toml` or `sound.test.toml` (shotglass README, "Metric
tests"): the metric run on fixed inputs from `tests/unit/quality/fixtures/` (small
`mainImage` or `mainSound` shaders), judged by limits like a film's `quality.toml`. A
must-fail case has to break a limit with valid measures, not error out. That's what
stops a metric going blind. `shotglass test tests/unit` runs them with the unit tests.

Keep a wide margin between each case's number and its limit (say what it measured in a
comment), so llvmpipe and real GPUs agree. A change to a metric's numbers changes every film's
reports: it's a breaking change (CONVENTIONS.md §7), noted in the release.

## Golden picture

CI renders selected frames of `tests/film` on Mesa (llvmpipe) and compares them with
[`tests/golden/film.png`](tests/golden) using `shotglass strip --compare` and its default
tolerance (a pixel differs when a channel is off by more than 8/255; at most 0.1% of
pixels may differ and the average difference must stay under 0.25/255). Real GPUs stay
inside that; a one-line change to a core function's output doesn't. The frames (one of
each scene, two transitions mid-way) are listed in the "Test film matches its golden
picture" step of [`ci.yml`](.github/workflows/ci.yml); add one if you add a scene.
`tests/animation` (core/animate.glsl) has its own reference, `tests/golden/animation.png`,
checked the same way by the "Animation film matches its golden picture" step, so a change
to an animation helper doesn't touch `film.png`; everything below applies to it too.
Likewise `tests/text` (text/, with its own fonts) and `tests/golden/text.png`, checked by the "Text
film matches its golden picture" step, and `tests/layers` (fx/ and blend/) with
`tests/golden/layers.png`, checked by the "Layers film matches its golden picture" step
(one frame per second: each blend mode, then each fx example).

On a failure, the run's `golden-failures` artifact holds the actual strip (`film.png`)
and `film.diff.png` (differing pixels in magenta). A change that should keep the pictures
the same must keep passing: never re-bless to make an unexplained difference go away. If
the picture is meant to change, write a new reference, look at it, and commit it with the
change:

- **From CI (preferred, it's what CI compares against):** every run uploads its render
  as the `test-film-strip` artifact (`film.png` and `animation.png`). Download it from the
  run of your branch and commit the one that changed under `tests/golden/`.
- **Locally:** run the command in the CI step with `--bless` added, e.g.

  ```sh
  xvfb-run -a shotglass strip tests/film --size 320x180 --cols 4 --out film.png \
    --at dusk+2.2,house+1.8,toys+1.6,garden+1.8,camera-orbit+2.6,camera-vertigo+2.0,toys+0.4,house-again+0.3,cellular+1,simplex-flow+1,blue-noise+1 \
    --compare tests/golden/film.png --bless
  ```

  Bless on Linux with Mesa when you can (or in shotglass's Docker image, see its
  CONTRIBUTING.md); a reference blessed on a real GPU usually passes too, but check that
  CI agrees before merging.

Moving `SHOTGLASS_REV` can change the pictures too (the engine draws the frames); re-bless
in the same commit if it does, and say why.

## Canary

CI builds shotglass at the commit pinned in `SHOTGLASS_REV`
([`ci.yml`](.github/workflows/ci.yml)), so an engine change can't turn this repository
red on its own; shotglass likewise tests against a pinned kit. The cost is that drift
goes unnoticed until someone moves a pin. [`canary.yml`](.github/workflows/canary.yml)
catches it early: every day (and on demand from the Actions tab) it runs the whole
CI job, with the same checks, strict GLSL check, Mesa renders, golden picture,
transition endpoints and audio references, against shotglass `main` instead. It never runs on pushes or pull requests, so
it can't block a merge. The run's summary and log name the shotglass commit under test,
and failing renders are uploaded as the `golden-failures` artifact.

A red canary means one of two things:

- **An engine change broke the kit's contract.** The kit is right; fix shotglass.
- **The kit relies on something that changed on purpose.** Update the kit, bump
  `SHOTGLASS_REV` to that shotglass commit (or later), and commit both.

To reproduce, build that commit (`cargo install --locked --git
https://github.com/antonmarsden/shotglass --rev <sha> shotglass`) and run the commands
the failing step shows.

## Releasing

Each folder's `library.toml` carries the version; all folders share the repository's
tags (`v0.1.0`). Bump the versions, then tag. Films only move to a new release with
`shotglass update`, so a release never changes a finished film, but within a minor
version (0.1.x), keep existing functions' output the same. What counts as breaking is
spelled out in [CONVENTIONS.md](CONVENTIONS.md#7-versioning).
