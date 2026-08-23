# Golden transcripts

49 expected transcripts: one per fixture at default options, plus every non-default
option on four hand-made files and two machine-generated ones. `GoldenTests.swift`
compares each byte for byte and reports a trimmed unified diff on failure.

**There is no regenerate-all flag, deliberately.** Regeneration in bulk turns every golden
into a restatement of current behaviour, which asserts nothing. When a change alters a
golden, read the diff, satisfy yourself the change is the one you meant, say which rule in
`SPEC.md` §6 produced it in the report to the user, and only then write the new text. An
unexplained golden diff is a failed step, exactly like an unexplained red test.

To regenerate one after that review:

```bash
swift build -c release
"$(swift build -c release --show-bin-path)/MagnificatCLI" \
  Tests/MagnificatTests/Fixtures/openscore/NAME.musicxml \
  > Tests/MagnificatTests/Golden/openscore/NAME.txt
```

## Review state

`SPEC.md` §7.7 requires every golden to be read by a person before it is committed, at a
depth proportionate to its length. This records what was actually done, on 23–24 August
2026, and by whom — all of it by Claude, none of it yet by a musician who reads by ear or
by braille.

| Golden | Depth | Outcome |
| --- | --- | --- |
| `webern-5-ihr-tratet-zu-dem-herde` | **Full**, 66 lines | **3 defects found.** A tempo mark split across three `<direction-type>` elements rendered as "Langsam (. ca 48)"; "poco rit." doubled its full stop; a SMuFL glyph inside `<words>` reached the transcript. |
| `parry-2-good-night` | **Full**, 137 lines | **1 defect found.** The part name printed twice, because the vocal line has a second voice. |
| `mayer-1-du-bist-wie-eine-blume` | **Full**, 126 lines | Clean. The piano part's lyrics summary looked wrong and was checked against the file: bar 26 genuinely cues two vocal syllables into the piano staff. |
| `davies-1-the-apology` | **Full**, 205 lines | **1 defect found.** "Allegro tranquilo Tempo: half note equals 96" — a redundant prefix on a metronome inside a larger marking. Also confirms the five-part path. |
| `organ-noordt-modern-engraving.zeus` | **Full**, 25 lines | Clean. Its 95 warnings were checked against the file: it declares `divisions=4` and then writes bar 4 as though it were 8. The file is wrong, and the check is right. |
| `brahms-3-o-tod`, `bridge-fair-daffodils`, `ferrari-le-sommeil` | Heading, first 10 and last 4 measures | Clean. |
| `beethoven-4-mailied`, `smyth-1-the-clown`, `satie-je-te-veux`, `joplin-please-say-you-will`, `chabrier-ballade-des-gros-dindons` | Heading, opening and closing measures — the long-file protocol | Clean. Smyth's "Words by Maurice Baring (1874–1945)" carries an en dash, which is what forced the invariant test to allow the file's own punctuation through while still forbidding it in the words Magnificat writes. |
| All 49, including every variant and every OMR file | **Automated scan** for doubled punctuation, empty phrases, stray whitespace, repeated words, and untranslated MusicXML tokens | **1 defect found**, across 247 lines: a lyric carrying the poem's own comma got the renderer's full stop appended, giving "lyric -ne,." |

**Not yet done, and it is the review that matters most:** nobody has read any of these with
a screen reader or on a braille display. Everything above is a sighted reading of text meant
to be heard or felt. `SPEC.md` §7.7 says the goldens exist partly so that a musician who
knows *Du bist wie eine Blume* can be handed its transcript and asked whether it describes
the song. That has not happened.
