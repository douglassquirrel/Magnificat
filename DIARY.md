# Diary — Magnificat

The running record of how this library got built. `CLAUDE.md` §Diary governs this file.

**If you are picking this up cold:** read `## Where things stand

*Rewritten in place every session. Last updated 23 August 2026.*

**Building. 26 tests, all green.** The renderer's value layer is done; the parser has not
been started.

| | |
| --- | --- |
| `SPEC.md` | Settled. §14 is a decision log. |
| Package | `swift build` and `swift test` both clean. Swift Testing, no dependencies. |
| Built | `Pitch`, `Step`, `KeySignature`, `AccidentalContext`, `AccidentalStyle`, `Accidental`, `NoteType`, `Tuplet`, `Duration`. |
| Tested | 26 tests: pitch spelling (§6.2), key signatures, accidental state, durations (§6.3). |
| **Not built** | **The parser.** No XML is read yet. Also: rests, chords, events, measures, directions, notations, lyrics, heading, layout, anomalies, CLI, README, goldens. |

### Next step

**The parser.** Everything so far renders hand-built values, which is the deliberate two-layer
split in `SPEC.md` §4 — but nothing yet proves a `<pitch>` element reaches `Pitch` correctly.
Three kinds of parser test, in this order:

1. **Small complete MusicXML documents inline in the test.** Not fragments — a fragment does
   not parse — but minimal `score-partwise` documents of a few lines, each provoking one thing:
   a missing `<voice>`, a `<backup>`, a note with no `<type>`, malformed input.
2. **Integration tests over the 31 real fixtures**, where assumptions about real-world MusicXML
   get falsified.
3. **Golden transcripts** (§7.7), once there is a transcript to golden.

Then: rests (§6.4) → chords (§6.5) → event stream and backup/forward (§6.6) → measures and
barlines (§6.12) → directions (§6.9) → notations (§6.10) → lyrics (§6.11) → heading (§6.13) →
layout and density (§6.7, §6.8) → anomalies (§6.15) → CLI → README.

---

## Log

*Append-only, newest last. Never rewrite a past entry; correct it in a new one.*

### 23 August 2026 — Read the brief; stopped because `SPEC.md` was blank

**Goal.** Understand the project before doing anything.

**What happened.** `CLAUDE.md` (212 lines) was complete and strict — portable Foundation-only
core, TDD with no exceptions, ≥90% coverage, CLI, README. `SPEC.md` was the untouched
skeleton, every section still the italic prompt.

**Decision.** `CLAUDE.md` says: *"If `SPEC.md` is still a blank skeleton, stop and ask the user
to fill it in. Do not invent requirements."* So I stopped and asked, rather than guessing at a
domain where guessing produces confident nonsense.

**Surprise.** The sibling project `../KunstDerFuge` is the other half of a pipeline: it turns
scanned sheet music **into** MusicXML; Magnificat turns MusicXML **into** readable text. Its
`SPEC.md`, `HANDOVER.md` and `docs/prototype-results.md` are the house style for this kind of
document, and its fixtures turned out to be exactly the test data this project needed.

**State.** Nothing built. Four questions to the user: output audience, notation coverage,
whether to follow an existing convention, and input strictness.

---

### 23 August 2026 — Surveyed the fixtures, drafted `SPEC.md`

**Goal.** Turn the user's four answers — screen reader / braille / large text, plain text only,
melody and voice-with-piano, no braille music — into a specification.

**What happened.** Rather than designing from imagination, I surveyed all twelve OpenScore
files element by element: 13,203 notes, 3,161 chords, 2,436 lyric syllables across up to three
verses, 2,160 slurs, 875 tuplets, 765 wedges, 26 grace notes, 18 repeats, 14 endings. No
`<transpose>` anywhere; all `score-partwise`.

**Decision / surprise.** Several rules came straight out of what the files actually contain and
would not have been guessed:

- Piano voicing is voices 1 and 2 on staff 1, 5 and 6 on staff 2, with `<backup>` between —
  so "two hands" is really "four voice streams".
- Parry has **no `<time>` element at all**. Its absence is information and gets its own line.
- Pickup measures are numbered `0` with `implicit="yes"`; measure numbers are strings, not ints.
- Key and time change mid-piece routinely — Ferrari restates the key 8 times, Webern the meter 20.

Two design calls worth remembering: dynamics are always prefixed (`Dynamic: piano`), because a
bare `Piano` is ambiguous with the instrument; and the transcript is a **list of structured
lines**, not a `String`, so a host app can build measure navigation without re-parsing text.

**State.** `SPEC.md` drafted, all 14 sections. Seven open questions raised.

---

### 23 August 2026 — Seven decisions; two errors caught in my own examples

**Goal.** Apply the user's answers and verify the worked examples.

**Decisions taken.** American duration names (no British option at all); `Time signature: 4 4`
with no solidus, always labelled; `A flat 4` with the octave on every note; `.perMeasure`
default; repeated pitches spelled out in full every time; any number of parts; copy in all the
fixtures.

**Surprise — and the reason §7 examples get verified against the source, not written from
memory.** `SPEC.md` §7 examples become tests verbatim, so I checked each against the Mayer XML.
Two were wrong: I had written a lyric on measure 6's final note that does not exist in the file,
and I had said the piece is 64 measures when it is 32 — `grep -c '<measure'` counts both parts.
Both would have become failing tests that looked like implementation bugs.

**State.** Decisions written into the governing sections.

---

### 23 August 2026 — Copied all 31 fixtures; the machine output broke four rules

**Goal.** The user asked why the fixture set was limited to three, and to copy in everything
relevant.

**What happened.** 31 files copied into `Tests/MagnificatTests/Fixtures/` in three sets:
`openscore/` (12 hand-made CC0, MuseScore), `omr-output/` (13 machine-generated, music21),
`omr-ground-truth/` (6 hand-verified excerpts). Deliberately excluded: the ~500 MusicXML files
vendored inside `KunstDerFuge/tools/prototype/.venvs/` (the music21 corpus — a dependency, not
fixtures) and `tools/prototype/out/` (scratch output).

**Surprise.** The user was right to push past three. The 19 machine-generated files broke four
rules the twelve hand-made ones had let stand:

1. **8 have no DOCTYPE.** The draft required validation against it — which would have rejected
   most of the output of the tool immediately upstream of this library.
2. **Blank part names and 32-character hash part IDs**, so selecting a part by name or ID is
   often impossible. Added `PartSelector.index(Int)`.
3. **A grand staff arrives as two separate one-staff parts.** So hand labelling now fires only
   where the file declares two staves. Magnificat does not guess — a wrong `Left hand` is worse
   than a dull `Part 2`, because the reader cannot catch it.
4. **6,170 of 6,494 notes have no `<staff>`; 3,317 have no `<voice>`; 23 have no `<type>`.**
   All three need defaults, and the inferred-duration rule went from defensive guess to
   documented requirement.

**State.** Fixtures in place with a README recording provenance and licences.

---

### 23 August 2026 — Validation: measured, and set aside

**Goal.** The user asked that incoming MusicXML be validated, and whether validation is possible
with no DOCTYPE. Full write-up in `docs/validation-experiment.md`.

**What happened.** Two findings, both measured rather than reasoned about.

*A missing DOCTYPE is no obstacle.* A DOCTYPE is a **pointer** to a schema, not the schema; a
validator supplies its own copy. All 31 fixtures validate offline against the MusicXML 4.0 XSD,
including all 9 with no DOCTYPE.

*Validation catches almost nothing that matters.* Seven corrupted copies of the Mayer were
tested. **Five passed**: the whole song shifted down an octave, a measure short by a beat,
`<duration>999</duration>` on a note typed `quarter`, every E flat respelled as E double-sharp,
and a note on staff 7 of a two-staff part. Only `<octave>banana</octave>` and malformed XML were
rejected — both of which the parser must catch anyway.

**Decision.** No schema validation in the core library. In its place, musical coherence checks
the schema cannot express — measure durations against the time signature, staff and voice
references in range, duration against notated type, backup before measure start — **reported as
`Transcript.anomalies`, never fatal**, because real OMR output is routinely incoherent and a
reader whose scan produced a ragged bar still wants the transcript. Deferred, not ruled out.

**Surprise, and it belongs to the other project.** KunstDerFuge's `HANDOVER.md` lists
validation-on-iOS as unverified because the machine had no Xcode. It does now. Tested directly:
`XMLDocument` genuinely does not exist on iOS (`cannot find 'XMLDocument' in scope` for
`arm64-apple-ios16.0`), but **libxml2 is in the iOS SDK**, and a Swift `xmlSchemaValidateDoc`
call compiles clean for iOS and gives verdicts identical to `xmllint`. That closes KunstDerFuge
§14.2. Someone should tell that project.

**State.** `SPEC.md` §6.15 written; `docs/validation-experiment.md` records the method so the
claim is reproducible rather than asserted.

---

### 23 August 2026 — Golden transcripts, and the diary itself

**Goal.** The user asked for an expected transcript per fixture, tested against; then for this
diary.

**Decisions.** `SPEC.md` §7.7 and §7.8. Every fixture gets a checked-in golden transcript
compared byte for byte, with a unified diff on failure; a subset also gets one per non-default
option. §7.8 adds a property test over every line of every golden asserting the §6.1 plain-text
invariants — ASCII outside lyrics, no tabs, no CRLF, an explicit deny-list for musical symbols
and emoji. That property test is the one most likely to catch a flat sign leaking into output
through a code path nobody considered.

**The point worth not losing:** a golden is a **reviewed artefact, not a recording of what the
code did**. There is no regenerate-all flag, and an altered golden must be justified — naming
the rule in §6 that produced the change — before it is committed. Without that, golden testing
quietly launders `CLAUDE.md`'s rule against editing tests to match unexpected output.

All 31 goldens will be reviewed: short ones in full, the five long ones (Beethoven 252 bars,
Smyth 222, Satie 220, Joplin 208, Chabrier 182) for their first and last twenty measures plus
every measure carrying an anomaly. Review state is recorded in
`Tests/MagnificatTests/Golden/README.md` so it survives a change of session.

**State.** `SPEC.md` settled at 800 lines with no open questions. `CLAUDE.md` amended with the
diary rule. This file created. **Still no code — the user is reading the spec first.**

---

### 23 August 2026 — Pitch spelling and accidental state (§6.2)

**Goal.** The first behaviour, chosen because it is where plausible-looking wrongness lives.

**Cycles.** Eight, each red before green: bare letter and octave; single accidentals; double
accidentals; key-signature alteration; the natural rule; measure-local accidental state;
barline cancellation; the `.asPrinted` style.

**Decision / surprise — this one changed the design.** Before writing the accidental machinery
I checked what `<alter>` actually means in the fixtures: **7,451 altered notes, and not one
case of a non-natural printed accidental without an `<alter>`**. MusicXML's `<alter>` is the
*sounding* alteration, already resolved by the exporter; `<accidental>` is only the printed
symbol. So `.sounding` reads `<alter>` directly and needs no key-signature arithmetic to spell
a pitch.

The key signature is still needed, but for a narrower job than `SPEC.md` §6.2 implies: deciding
when the word `natural` is worth saying. A bare letter has to mean "unaltered, and nothing in
force would have altered it", so `A` in A flat major must be `A natural 4` while `C` in the
same key is just `C 5` — which is exactly what §7.1, verified against the file, expects.

**Also worth keeping.** The octave-scoping test passed the moment it was written, because
nothing was recorded yet. Rather than delete it or shrug, it was mutation-checked: keying
accidentals on step alone makes it fail with `"C natural 5" == "C 5"`. It does guard what it
claims to. Vacuous-on-arrival tests are worth this check rather than a note.

**State.** 15 tests green.

---

### 23 August 2026 — Durations (§6.3)

**Goal.** Name a note value in American terms, with dots, tuplets, and inference.

**Cycles.** Four: type names; dots; tuplets; inference from divisions.

**Decision / surprise.** Each rule was checked against the corpus first rather than designed
from the spec alone, and each check changed something:

- **Dots reach two, never three** (1,267 single, 2 double, 18,428 plain). Three dots is legal
  MusicXML though, so it is named `half with 3 dots` rather than silently dropped.
- **Tuplet ratios are 3:2, 6:4, 4:6, 2:1 and 2:3.** So 6:4 must be `sextuplet`, not `triplet` —
  reducing the ratio first would have named it wrongly. Named: duplet, triplet, quintuplet,
  sextuplet. Everything else takes the ratio form, including 7:4, following §6.3's own example.
- **music21 emits `<time-modification>` of 1:1** — a modification that modifies nothing.
  Speaking "1 in the time of 1" would be noise, so a trivial ratio is ignored.
- Inference is done in **exact integer arithmetic**, never floating point, and tries longest
  value first so a length is named by the largest note that fits it rather than by an
  equivalent with more dots. Where nothing fits exactly it says `duration 5 divisions` rather
  than guessing, as §6.3 requires. `perQuarter: 0` is guarded — dividing by a `<divisions>` of
  zero would crash on a file that could plausibly exist.

**State.** 26 tests green. Parser next.
