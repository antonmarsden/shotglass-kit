# shotglass-kit/fonts

Fonts for shotglass [text blocks](https://github.com/antonmarsden/shotglass#text), so a
film can set titles without bringing its own. Fonts only, no GLSL; draw the blocks with
[`text/`](../text) (README, "Text").

```toml
# shotglass.toml
shotglass = "0.1.3"

[libraries]
fonts = { version = "0.1", source = "https://github.com/antonmarsden/shotglass-kit", subdir = "fonts" }
```

```toml
# movie.toml
[fonts]
body = { file = "<fonts/inter/Inter-Variable.ttf>" }
bold = { file = "<fonts/inter/Inter-Variable.ttf>", variations = { wght = 700 } }
title = { file = "<fonts/bungee/Bungee-Regular.ttf>", fallback = ["body"] }
```

| file | family | what it's for | axes |
|---|---|---|---|
| `inter/Inter-Variable.ttf` | [Inter](https://github.com/rsms/inter) | a neutral sans for body text, captions, credits; Latin, Greek, Cyrillic | `wght` 100–900, `opsz` 14–32 |
| `atkinson-hyperlegible/AtkinsonHyperlegible-Regular.ttf`, `-Bold.ttf` | [Atkinson Hyperlegible](https://github.com/googlefonts/atkinson-hyperlegible) | subtitles and small text: letters designed not to be confused with each other (Braille Institute); Latin | – |
| `bungee/Bungee-Regular.ttf` | [Bungee](https://github.com/djrrb/Bungee) | a bold display face for titles and signs, capitals only (lower case sets as capitals); Latin | – |

Shotglass hints nothing and never reads system fonts, so text looks the same on every
machine. A letter none of a block's fonts has is an error naming it; use `fallback` to
fill gaps (Inter covers more scripts than the others).

## Licence

Every font here is under the [SIL Open Font License 1.1](https://openfontlicense.org)
(`licences = ["OFL-1.1"]` in `library.toml`), with its family's `OFL.txt` next to it.
[`LICENSE-OFL.txt`](LICENSE-OFL.txt) collects every family's copyright notice and the
licence in one file, which `shotglass bundle` and `freeze` copy along with the fonts.
The OFL allows using the fonts in any film, commercial ones included, and embedding them;
a rendered or exported film contains pictures of text, not the fonts, and the OFL puts no
condition on that. Redistributing the font files themselves (a bundle of the film, say)
means keeping each family's `OFL.txt` with them and not selling the fonts on their own.

The files are unmodified (byte for byte) from [google/fonts](https://github.com/google/fonts)
at commit `06bfe0d62a98375cb09c942fa18e68bd32cff057`:

| here | from google/fonts | sha256 |
|---|---|---|
| `inter/Inter-Variable.ttf` | `ofl/inter/Inter[opsz,wght].ttf` (renamed: no brackets in paths) | `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031` |
| `inter/OFL.txt` | `ofl/inter/OFL.txt` | |
| `atkinson-hyperlegible/AtkinsonHyperlegible-Regular.ttf` | `ofl/atkinsonhyperlegible/AtkinsonHyperlegible-Regular.ttf` | `7fb917c89019896d0b52ee84b7cbb3304c18cb90b19a62f5e32712bd23e97669` |
| `atkinson-hyperlegible/AtkinsonHyperlegible-Bold.ttf` | `ofl/atkinsonhyperlegible/AtkinsonHyperlegible-Bold.ttf` | `5a3b0c8cc8ca545155150b4512a1fa248298df121c50d6557e651e61fbdab92f` |
| `atkinson-hyperlegible/OFL.txt` | `ofl/atkinsonhyperlegible/OFL.txt` | |
| `bungee/Bungee-Regular.ttf` | `ofl/bungee/Bungee-Regular.ttf` | `c4f5361ce120af3e6b9156d0bf379fa19cda2ea0cd18ac01fd99596c6bf66e3f` |
| `bungee/OFL.txt` | `ofl/bungee/OFL.txt` (CRLF line ends kept: `-text` in `.gitattributes`) | |

## Versioning

Adding a font is a patch release. Removing one, or replacing it with another version of
the same family (which can change how text sets: widths, kerning, line breaks), is a
breaking change, like changing a function's output. A film pins the kit, so its fonts
never change under it. How to add one: "Adding a font" in
[CONTRIBUTING.md](../CONTRIBUTING.md).
