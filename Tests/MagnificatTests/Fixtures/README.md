# Test fixtures

31 MusicXML files copied from `../../../../KunstDerFuge/Fixtures/` on 23 August 2026. All are
`score-partwise`; all are well-formed and parse. Between them they cover both exporters
Magnificat is likely to meet, hand-engraved and machine-generated input, and every structural
feature §6 of `SPEC.md` describes.

Do not edit these files. Where a test needs a specific malformed or degenerate input, write a
small XML literal inline in the test instead — these stay as they arrived.

## `openscore/` — 12 files, 4.6 MB

Hand-made CC0 transcriptions from the [OpenScore Lieder Corpus](https://github.com/OpenScore/Lieder),
exported by **MuseScore 4.5.2**, MusicXML 4.0, all with a DOCTYPE. Eleven are voice and piano;
`davies-1-the-apology.musicxml` is SATB plus piano (5 parts). These are the primary fixtures: they
are correct music, they carry lyrics, and they are what a user's own files will look like.

`manifest.json` came with them and records key, meter, bar count and note count per file, plus
the IMSLP source each was transcribed from.

Notable for testing:

| File | Why it is here |
| --- | --- |
| `mayer-1-du-bist-wie-eine-blume.musicxml` | 32 bars, A flat major, 4/4. The worked examples in `SPEC.md` §7 come from this file. |
| `parry-2-good-night.musicxml` | **No `<time>` element anywhere** — unmetered. |
| `webern-5-ihr-tratet-zu-dem-herde.musicxml` | 41% of notes off-key; dense accidentals; 20 meter changes. |
| `ferrari-le-sommeil.musicxml` | 8 key changes, 18 meter changes. |
| `davies-1-the-apology.musicxml` | 5 parts (SATB + piano) — the multi-part path. |
| `smyth-1-the-clown.musicxml` | Largest, 692 KB / 222 bars — the performance fixture. |
| `beethoven-4-mailied.musicxml` | 252 bars; repeats and endings. |

Licence: CC0 1.0 Universal. Redistribution is unrestricted.

## `omr-output/` — 13 files, 1.3 MB

**Machine-generated** MusicXML: the output of the OMR models KunstDerFuge evaluated, converted by
**music21 v10.5.0** or emitted directly by the recogniser. MusicXML 3.1 and 4.0. This is what the
real KunstDerFuge → Magnificat pipeline will actually hand Magnificat, and it is far scruffier
than the OpenScore files:

- **8 of the 19 machine files carry no DOCTYPE at all.** The parser must not require one.
- **Part names are frequently empty**, and part IDs are 32-character hashes
  (`P58e8fbbebb43b723db0df2713a2b15cc`) rather than `P1`. Naming and part selection cannot rely
  on either.
- **A piano grand staff arrives as two separate one-staff parts**, not one two-staff part — and
  sometimes named `Upper staff` / `Lower staff`, sometimes `Staff 1` / `Staff 2`, sometimes not
  at all. One file has a part named `Zeus`, after the model that produced it.
- **6,170 of 6,494 notes have no `<staff>`** and **3,317 have no `<voice>`**; both must default
  to 1.
- **23 notes have no `<type>`**, so the duration name has to be inferred from `<duration>` and
  the prevailing `<divisions>` (`SPEC.md` §6.3).
- **No lyrics at all.** OMR does not yet recover text.

## `omr-ground-truth/` — 6 files, 356 KB

Hand-verified excerpts of the same pages, used by KunstDerFuge as the reference to score OMR
output against. Same scruffy provenance as `omr-output/` but musically correct, so a transcript
of one of these can be checked by eye against the corresponding scan.

## Provenance of the sources

The OpenScore transcriptions are CC0. The OMR output and ground-truth excerpts were produced
within KunstDerFuge from public-domain IMSLP scans; `../KunstDerFuge/Fixtures/manifest.json` and
`docs/prototype-results.md` record which scan each came from.
