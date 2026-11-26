# Kit conventions

The written contract for code in shotglass-kit. Every library in this repository
follows it, and every pull request and issue that adds to the kit is checked against
it. [CONTRIBUTING.md](CONTRIBUTING.md) covers licensing and the mechanics of a pull
request; this file covers what the code has to be.

A rule here can be broken only by listing the exception at the bottom of this file,
with the reason.

## 1. Names

- **Prefix.** Public functions, structs and constants start with the library's prefix:
  `kit_` for everything in this repository. Internals start with `kit_private_`
  (`kit_private_unit`). A third-party library uses its own prefixes (`toon_`,
  `toon_private_`). Avoid two consecutive underscores in GLSL identifiers for
  compatibility with browsers that reject them.
- **Shape:** `kit_<area>_<thing>` when a file holds a family (`kit_sd_box`,
  `kit_op_smin`, `kit_ease_smooth`); plain `kit_<thing>` otherwise (`kit_hash`,
  `kit_fbm`, `kit_aces`). Lower case, words split with `_`.
- **Overloads, not suffixes**, for the same operation on other types:
  `kit_hash(ivec2)` and `kit_hash(ivec3)`, not `kit_hash2` and `kit_hash3`. A new overload
  must not change which overload an existing call picks (see [Versioning](#7-versioning)).
- **No global state.** No global variables, no `#define`s that leak names, no
  `precision` statements (the engine sets `highp`). Any file can be included in any
  order; the engine includes each file once. Files may include their siblings
  (`#include "noise.glsl"`).
- **Transition and pass parameters** are the one exception to "no `#define`s": they're
  the transition's (or the `fx/` pass's, or the blend's) interface, written with an
  `#ifndef` default. Because a parameter is a macro, it rewrites every matching
  identifier in the file's own includes, so a pass that includes other files must use
  parameter names that don't occur in them (`fx/ops.glsl` names its function parameters
  `lo` and `gn`, because the grade's params are `lift` and `gain`). Animatable inputs of
  an `fx/` pass are uniforms (`uExposure`), defaulted with `#ifndef SG_HAS_<name>`.

## 2. Parameters and units

**Order.** The thing being worked on first, then what shapes it, then options:
`kit_sd_box(p, b)`, `kit_vignette(uv, amount, softness)`, `kit_grain(col, fragCoord, frame, amount)`.
A function that mirrors a GLSL built-in keeps the built-in's order
(`kit_tween(from, to, t)` reads like `smoothstep(edge0, edge1, x)`).

**Parameter names** are short and reused across the kit with the same meaning:

| name | meaning |
|---|---|
| `p` | a position (2D or 3D), in the caller's units |
| `uv` | frame position, 0..1 on each axis (`fragCoord / iResolution.xy`) |
| `fragCoord` | pixel position, as passed to `mainImage` |
| `x`, `t` | a 0..1 amount (eases), or time in seconds (`t` only when it's time) |
| `col` | a colour |
| `r` | a radius; `b` a half-size; `k` a blend or fillet size |
| `amount` | strength, 0..1 unless the header says otherwise |
| `softness` | edge blur, in the units of the distance it blurs |
| `seed`, `frame` | integers fed to a hash |
| `samp` | a sample index, as passed to `mainSound` |

**Units.** Say them in the header, every time. Use these unless there is a reason not to:

| quantity | unit |
|---|---|
| time | seconds (never frames or samples, except a `frame` or `samp` index) |
| angle | radians |
| frequency | hertz (sound), cycles per unit (noise) |
| proportions, mix amounts, progress | 0..1 |
| lengths in 2D/3D space | the units of `p` |
| lengths on screen | frame heights, so a circle stays round at any aspect ratio |
| colour | 0..1 per channel; the header says whether it's **linear** (light, before `kit_aces`) or **display** (what goes on screen, after `kit_srgb_encode`). Shots and transitions output display colour |
| gain | linear amplitude (0.5 is half as loud as 1.0), not decibels |

**Ranges.** A function either clamps its input to the documented range or says what
happens outside it (`kit_fbm` takes 1..12 octaves; `kit_op_repeat` needs `s > 0`).
Never divide by a parameter that can be zero without a guard
(`max(dot(ba, ba), 1e-12)`).

## 3. Determinism

A frame depends only on (film, time, size, render scale), and a sample only on (film,
sample index). The kit must not add other inputs, and must keep results as close
across GPUs as GLSL allows.

- **Integer hashes are exact.** Randomness comes from `kit_hash` / `kit_hash_u`
  (`core/noise.glsl`): 32-bit unsigned integer arithmetic, which wraps the same way at
  GLSL 3.30 and GLSL ES 3.00 (`highp`). They give the same bits everywhere.
- **No `sin()` hashes** (`fract(sin(x) * 43758.5453)`) or anything else that
  multiplies a float rounding error into a visible difference. Built-in functions like
  `sin`, `pow` and `exp` differ by a few ULPs between drivers; code must stay smooth
  in those errors, so a tiny input difference gives a tiny output difference.
- **No implementation-defined built-ins** where the choice shows: `round()` may go
  either way at .5 (use `floor(x + 0.5)`); converting a float outside the `int` range
  to `int` is undefined (document the input range, or clamp first).
- **No state between frames or samples.** No feedback, no reading the previous frame,
  no time accumulated across calls: shotglass renders any frame and any chunk of
  sound on its own, in any order.
- **No driver-dependent features:** no `gl_FragCoord` inside library code (take
  `fragCoord` as a parameter), no extensions.
- **Same results at GLSL 3.30 core and ES 3.00.** Both get `highp` float and int;
  don't rely on more (no `double`, no 64-bit ints).

## 4. Precision

The engine compiles with `precision highp float; precision highp int;` on GLSL ES, so
assume IEEE single precision (24-bit significand) and 32-bit integers, no more.

- **Integer literals** that don't fit in `int` need the `U` suffix (`0x9e3779b9U`).
  Signed overflow is wrapping on both targets, but write hashes in `uint` so the
  intent is clear.
- **Float → int:** only for values known to be well inside ±2^31; `ivec2(floor(p))` is
  fine for any sensible position, but say "p up to about ±10^6" in the header when
  float precision of the input itself starts to show (cells repeat or smear above
  about 2^22).
- **Exact constants:** `1.0 / 16777216.0` and the like are exact; write constants with
  enough digits (`6.28318531`, not `6.28`).
- **Long times lose precision.** At 10 minutes, a float holding seconds has a step of
  about 6e-5 s: fine for animation, audible as jitter in a 1 kHz oscillator. Sound code
  should keep phase arguments small by working from the integer `samp`: for example
  `float(samp % rate) / float(rate)` is the exact time within the current second
  (`rate = int(iSampleRate)`), which is all a whole-hertz oscillator needs. Never
  `sin(6.2831 * f * time)` with a large `time`.
- **No precision qualifiers** in kit code. Samplers other than `sampler2D` need
  `highp` on ES (`uniform highp sampler3D t;`), but kit code doesn't declare uniforms.

## 5. Picture and sound

Library code may be included by scene shaders, transitions, shot sounds, music and the
mix. They don't share an environment:

| | scenes, transitions | `mainSound` (music, shot sounds), `mainMix` |
|---|---|---|
| uniforms | `iTime`, `iResolution`, `iFrame`, … | `iSampleRate` only (shot sounds: also `iShotStart`, `iShotDuration` and the shot's uniforms) |
| one invocation is | a pixel | a sample |
| derivatives (`dFdx`, `dFdy`, `fwidth`) | yes | **no**: neighbouring invocations are unrelated samples, laid out differently for each chunk size |
| `texture()` with implicit LOD | yes | **no** (uses derivatives); `texelFetch` / `textureLod` only |
| `discard`, `gl_FragCoord` | scene code only, never in a library | **no** |

So:

- **Library code references no uniforms.** Take time, resolution and frame as
  parameters (`kit_grain(col, fragCoord, frame, amount)`). Then a function works in
  both picture and sound.
- **Each file says in its header whether it's sound-safe.** A sound-safe file uses no
  derivatives, no implicit-LOD `texture()`, no `gl_FragCoord`, no `discard`, and only
  includes other sound-safe files. Write `// sound: yes` or `// sound: picture only`
  in the file header (or `// sound: mix only` / `// sound: metric only`, below). A test film's music includes
  every sound-safe file, so
  glslang rejects a picture uniform in one; derivatives would still compile there
  (sound shaders are fragment shaders too), so CI also greps sound-safe files for
  `dFdx`, `dFdy`, `fwidth`, `gl_FragCoord`, `discard` and `texture(`.
- **Mix-only files** call the engine's `music(samp)` / `sfx(samp)`, which exist only in
  a `mainMix` shader, so they say `// sound: mix only`. They follow the sound-safe
  rules otherwise, take the sample rate as a parameter (`rate`, as `int(iSampleRate)`)
  rather than reading the uniform, and a test film's `mix.glsl` includes each one.
  Mix reads are deterministic only within the window the engine keeps: `mix_lookback`
  seconds back (default 1) and 50 ms ahead. Clamp look-aheads to 50 ms, and say in
  the header how far back each function reads (`reads: up to ... seconds back`).
  No feedback either (§3): an echo is a sum of fixed taps, never a reading of the
  mix's own output.
- **Sound metrics** (`quality/sound/`, `// sound: metric only`) run in `shotglass quality`'s
  sound metric shader, reading the soundtrack with `getSound(samp)`; they follow the
  sound-safe rules but are never included by music or a mix.
- **Sound output** is `vec2` (left, right) in -1..1. Library sound functions return a
  level around ±1 and leave the gain to the caller; they never clip (except
  `kit_soft_clip`, whose job it is).

## 6. Tests

- **Every public function is called by a test film** (`tests/film` or `tests/animation`, or `tests/sound`
  `tests/instruments` and `tests/mix` for the `sound/` library, or `tests/text` for `text/`): a scene, a transition,
  the music or the mix. Calling it, not just
  including the file, so a reviewer can see what it does in the strip (or hear it) and
  so the GPU compiles the code path that matters. CI fails if a file isn't included or
  a public function isn't called.
- **`fx/` and `blend/`** keep their maths in one file (`fx/ops.glsl`, `blend/modes.glsl`)
  and each pass is a few lines of `mainImage` or `blend` around it, because unit tests
  have no scene uniforms. The functions are called by the passes, which `tests/layers`
  draws (a layer with `type = "fx/<name>"` or `blend = "blend/<name>"`; CI checks that
  every file is used that way, or included by a pass). Premultiplied alpha is handled
  only in `kit_blend_source` and `kit_blend_composite`.
- **Every public function's contract has a unit test** in `tests/unit/` (`shotglass
  test`): the header's endpoints, ranges and identities, as `expect*` assertions run on
  the GPU, including property tests over the whole documented input range. The header
  is the spec; when a test and the code disagree, one of them is wrong. CI checks that
  every public function is called from `tests/unit/`, except in mix-only files (they
  read the mix's buses, which only a mix shader has; `tests/mix` covers them).
- **Quality metrics fail when they should.** Each `quality/` metric has a must-pass
  and a must-fail metric test (`tests/unit/quality/*.test.toml`, run by `shotglass test`):
  the first must hold its limits, the second must break them.
- **Sound has a reference.** Each sound test film's soundtrack (`tests/sound`,
  `tests/instruments`, `tests/mix`) is compared with `tests/golden/<film>.wav` (8 kHz, rendered on Mesa) within `shotglass wav --compare`'s
  default tolerance. A change that should keep the samples the same must keep passing;
  one that changes them on purpose re-blesses the reference in the same commit.
- **Everything passes `shotglass check tests/film --web --strict --no-gpu`**: glslang at GLSL
  3.30 core and as GLSL ES 3.00, with browser compatibility warnings treated as
  errors. CI also compiles the simplex-flow scene in Chromium WebGL 2.
- **Look at it.** `shotglass strip tests/film --count 8 --out strip.png` (CI uploads
  one too). A change that should keep the pixels the same should keep the strip the same.
- **Transitions** show exactly the old shot at `progress = 0` and exactly the new one
  at `progress = 1`, at every parameter value.

## 7. Versioning

The kit's promise: **a release never changes a finished film.** A film pins the
exact commit in `shotglass.lock` and moves only with `shotglass update`, which stays
within the film's version range (`version = "0.1"` means 0.1.x). So the question
is what may change within a range.

Each folder's `library.toml` has its own version; all folders share the repository's
tags. Before 1.0, the minor number is the breaking one (0.1 → 0.2), as in Cargo.

**Breaking** (next minor before 1.0, next major after):

- Removing or renaming anything public, or changing a signature (including a
  transition parameter's name or default).
- **Changing the output** of an existing function for any input it documents, beyond
  the float differences between drivers. Different pixels or samples are a breaking
  change even when the old output was a bug. Ship the fix in the next breaking
  release; if it can't wait, add a new function alongside.
- Adding an overload that changes which overload an existing call resolves to.
- A new `#include` in an existing file that brings in a name a film could already be
  using, outside the library's prefix.
- Raising `requires_shotglass` or `glsl` in `library.toml`.

**Not breaking** (patch, 0.1.x):

- New functions, files and transitions; new overloads for types that had none.
- Changes that keep every output the same (refactors, faster code with identical
  results, comments and docs).
- Making implementation-defined behaviour defined, when the new result is one the
  old code could already give on some driver (`round()` → `floor(x + 0.5)` at .5).

When unsure, treat it as breaking.

## 8. Doc comments

Every file starts with a header:

```glsl
// shotglass-kit/core: noise.glsl
//
// What the file is for, in a sentence or two, and anything that applies to every
// function in it.
// sound: yes
```

Every public function, or group of overloads, has a header directly above it. A user
(or an AI) should never need to read the body:

```glsl
// kit_value_noise(p): smooth noise, cells 1 unit wide.
//   p   any position; scale it for bigger or smaller blobs
//   ->  0..1
//   cost: 4 hashes (vec2), 8 (vec3)
//   e.g. float n = kit_value_noise(uv * 8.0);
```

- First line: the call with its parameter names, then what it does in one sentence.
- One line per parameter: name, then units and range, aligned.
- `->` the result, with its range and units.
- `cost:` in terms a shader writer can compare (hashes, noise lookups, a raymarch
  step's worth). Leave it out when it's a few arithmetic operations.
- `e.g.` one or two lines of real use, which must compile when pasted into a
  `mainImage`.
- Short functions with obvious parameters (one-line SDFs, `kit_op_union`) may use a
  one-line header, as long as it names every parameter's meaning and units.
- Transitions document their parameters at the top of the file, one per line:
  name, type and range, meaning, `(default …)`, then `cost:` and an `e.g.` with the
  `movie.toml` line.

Plain words, British or American spelling consistently within a file, no marketing.

## Exceptions

Existing code that doesn't follow these rules, and why.

| where | rule | why it stays |
|---|---|---|
| `transitions/dissolve.glsl` | §3 no `sin()` hashes | Renders exactly like the engine's deprecated built-in `dissolve`, so films can move to the kit without their pixels changing. A deterministic dissolve can come as a new transition. |
| `transitions/wipe.glsl` | §2 screen lengths in frame heights | `softness` is in uv units (0..1 on each axis), as in the engine's built-in `wipe`, for the same reason. |
| `fx/dither-ops.glsl` | §6 fx maths in `fx/ops.glsl` | Shares core rounding through its canonical include while keeping the other passes independent of the core library. |
