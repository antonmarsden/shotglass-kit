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

- **Prefix** public functions `kit_` and helpers `kit__`.
- **Header contract** above every public function: what it does, each parameter with
  units and range, what it returns, cost, and a one-line example. Copy the style of
  `core/noise.glsl`.
- **Portable GLSL:** GLSL 3.30 core features only, and valid GLSL ES 3.00: float
  literals (`1.0`, not `1`), `U` on unsigned literals, no implicit int→float.
  `shotglass check tests/film --web --no-gpu` checks this; your GPU's driver alone
  isn't proof (NVIDIA accepts code others reject).
- **Deterministic:** no `sin()` hashes or other GPU-dependent tricks in new code. Use
  `kit_hash` from `core/noise.glsl`.
- **No global state:** no global variables, no `#define`s that leak names (a
  transition's parameter `#define`s are the exception: they're its interface).
- **Use it in a test film** (`tests/film`; `tests/sound` or `tests/instruments` for the `sound/` library): CI
  fails if a library file isn't included or a public function isn't called. A sound-safe
  file (`// sound: yes`) is also included by a test film's `music.glsl`, so it's checked
  as a sound shader too.
- **Sound changes:** CI compares the soundtracks of `tests/sound` and `tests/instruments` with
  `tests/golden/sound.wav` and `tests/golden/instruments.wav`.
  If the sound is meant to change, re-bless the reference (README, "Audio references"),
  listen to it, and commit it with the change.

## Adding a transition

A transition defines `vec4 transition(vec2 uv)` using `getFromColor(uv)`,
`getToColor(uv)`, `progress` (0..1) and `ratio` (width / height). Parameters are
`#define`s with `#ifndef` defaults, documented at the top. It must show exactly the
old shot at `progress = 0` and exactly the new one at `progress = 1`.

## Canary

CI builds shotglass at the commit pinned in `SHOTGLASS_REV`
([`ci.yml`](.github/workflows/ci.yml)), so an engine change can't turn this repository
red on its own; shotglass likewise tests against a pinned kit. The cost is that drift
goes unnoticed until someone moves a pin. [`canary.yml`](.github/workflows/canary.yml)
catches it early: every day (and on demand from the Actions tab) it runs the whole
CI job, with the same checks, strict GLSL check, Mesa renders and audio references,
against shotglass `main` instead. It never runs on pushes or pull requests, so
it can't block a merge. The run's summary and log name the shotglass commit under test,
and a failing audio reference is uploaded as an artifact.

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
