---
name: New kit code
about: A new library, file, function or transition for the kit
---

<!-- Everything in the kit follows CONVENTIONS.md:
     https://github.com/antonmarsden/shotglass-kit/blob/main/CONVENTIONS.md -->

**What it adds**


**Public API** (names, parameters with units and ranges, return value; see CONVENTIONS.md §1, §2, §8)


**Picture, sound or both** (CONVENTIONS.md §5)


**Done when**
- [ ] Follows [CONVENTIONS.md](https://github.com/antonmarsden/shotglass-kit/blob/main/CONVENTIONS.md), or lists its exceptions there
- [ ] Every public function is called by `tests/film` (sound-safe files also by `tests/film/music.glsl`)
- [ ] `shotglass check tests/film --web --strict --no-gpu` passes
- [ ] Versioning: says whether it's a patch or a breaking change (CONVENTIONS.md §7)
