# Diary — Magnificat

The running record of how this library got built. `CLAUDE.md` §Diary governs this file.

**If you are picking this up cold:** read `## Where things stand

*Rewritten in place every session. Last updated 24 August 2026.*

**The library is built and complete.** 196 tests, all green. `swift build`,
`swift test --enable-code-coverage` and `swift run MagnificatCLI --help` all succeed.

| | |
| --- | --- |
| `SPEC.md` | Settled. §14 is a decision log. Amended five times while building — each amendment says why, in place. |
| Library | `Sources/Magnificat/`, Foundation only. Verified to compile for `arm64-apple-ios16.0`, the iOS simulator, and macOS. |
| CLI | `Sources/MagnificatCLI/`. Every flag in `SPEC.md` §12, distinct exit codes, 18 tests. |
| Tests | **201**, four layers: units, parser tests on complete inline documents, integration over 31 real files, and 49 goldens plus invariants. |
| Coverage | **98.2% of lines**, 93.1% of regions. `CLAUDE.md` asks for ≥90%. |
| `README.md` | Complete. Every Swift snippet is also a test, verbatim, so it cannot rot. |
| Goldens | 49, all reviewed. `Tests/MagnificatTests/Golden/README.md` records the depth of each. |

### What is not done

- **No blind or low-vision musician has read a word of the output.** Everything has been
  checked by eye — the one sense the output exists not to need. This is the most valuable
  review remaining and nothing substitutes for it.
- **`transcribe()` has no streaming form.** The largest fixture renders in well under a second,
  so nothing yet needs one.

### Where to start reading the code

`Sources/Magnificat/AccidentalContext.swift` and `Renderer.swift` hold the subtlety. The
parser is long but flat. `Coherence.swift` is where the anomaly checks live, and its comments
record which real file falsified each earlier version of them.

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

---

### 23 August 2026 — The parser, and a cross-check that cannot flatter itself

**Goal.** Read MusicXML into the score model.

**Cycles.** Five, plus the error cases. Tested three ways, as promised to the user when they
asked — mid-work — whether the tests were exercising any parsing at all. They were not, at
that point: the first fifteen tests ran on hand-built values. The answer was to say so
plainly and to name the three layers that were coming.

**Decision / surprise.** The strongest test available turned out to be OpenScore's own
`manifest.json`, which records note and measure counts **computed independently of this
library**. A golden that this library generates can drift to match a bug; that manifest
cannot. All twelve agree exactly.

Getting them to agree is what found grace notes: the manifest counts pitched notes and
excludes graces, and matching it required parsing `<grace/>` — which the model needed anyway,
since a grace note carries no duration and must stay out of the timing arithmetic.

**State.** 42 tests green.

---

### 23 August 2026 — Rendering, and a spec violation I introduced myself

**Goal.** Measures, chords, streams, layouts, densities, directions, notations, lyrics.

**Decision / surprise — the one worth remembering.** Splitting a part into streams broke
`SPEC.md` §6.2 without breaking a single test. An accidental is in force across every voice
and staff of a part until the barline, but streams render one after another, so accidental
state that follows the rendering order never reaches the other hand: a C sharp in the right
hand left a C in the left reading `C 4` instead of `C natural 4`. Pitch names are now settled
for the whole part, measure by measure across all voices, before any stream is rendered.

The red test is two notes. It is the kind of defect this library exists to prevent — a
confident, plausible, wrong instruction to somebody who cannot check it — and no unit test
would have caught it, because every unit was right.

**Also found by tests.** Giving directions a synthetic voice number invented a phantom stream
carrying nothing but directions. And a stream emitted a bare `Measure 4.` for every measure it
was silent in — the Mayer's vocal line has a second voice with seven notes across 32 measures,
so the transcript filled with lines that said nothing. `SPEC.md` §6.6 gained that rule.

**State.** With those fixed, `SPEC.md` §7.1 to §7.5 render verbatim from the real file. They
were written and hand-verified against the XML before any renderer existed, so they are ground
truth for the whole pipeline rather than a restatement of what the code does.

---

### 23 August 2026 — Anomalies, and a check that fired on correct music

**Goal.** The coherence checks that replace schema validation (§6.15).

**Decision / surprise.** The first version reported any measure whose durations did not match
its meter. It fired on the Davies — which is correct music. Bar 6 holds 12 divisions and bar 7
holds 4, and they sum to a full bar across a repeat barline. Short bars are routine: a pickup,
the bar before a repeat, the bar closing a first ending. Telling a legitimate one from a
defective one needs the repeat structure modelled, which is out of scope.

**An anomaly that fires on correct music trains a reader to ignore anomalies**, which is worse
than not checking at all. Only overfull bars are reported now — those are unambiguous.

A second version summed each voice's durations and still fired, because `<forward>` skips time
without producing an event: a voice resting by skipping rather than by writing rests looked
short. The check now measures where a voice *ends*.

The assertion that found both was "no hand-made fixture reports anything". All twelve
OpenScore files are silent; all 114 warnings across the corpus come from OMR output. The
loudest, 95 of them, is a file that declares `divisions=4` and then writes bar 4 as though it
were 8 — real incoherence, which the schema passes.

**State.** 129 tests green.

---

### 23–24 August 2026 — Golden review, which found seven defects

**Goal.** 49 goldens, and the review `SPEC.md` §7.7 requires before any of them is committed.

**Decision / surprise.** This is the entry to read if you read only one. **Every one of these
defects was in output that the entire unit suite passed**, and every one would have reached a
reader who could not check it:

1. The Webern's tempo is one `<direction>` split across three `<direction-type>` elements —
   `"Langsam ("`, a metronome with an empty `<per-minute/>`, then `"ca 48)"`. Rendering them as
   separate phrases gave `Langsam (. ca 48)` and dropped the metronome; joining them raw gave
   `quarter noteca 48`, because the space between them was the glyph's own width.
2. `poco rit.` rendered as `poco rit..`
3. **A SMuFL music glyph inside `<words>`, and two more inside a `<lyric>` in the Satie** —
   Private Use codepoints reaching the transcript as invisible characters. This is exactly the
   failure §7.8's invariant test was written to catch, found in the wild on the second file
   reviewed.
4. The Parry printed `Voice` twice, because its vocal line has a second voice and the first
   stream's label is the part name.
5. `Allegro tranquilo Tempo: half note equals 96` — a prefix that only makes sense on a
   metronome standing alone.
6. A lyric carrying the poem's own comma got the renderer's full stop appended: `lyric -ne,.`,
   across 247 lines. Found by scanning every golden for doubled punctuation rather than by
   reading, which is worth doing before reading: it focuses the eye.
7. Restricting to a measure range lost the key, meter and divisions, because MusicXML states
   them once and leaves them standing. The heading said `No time signature`, and the accidental
   rules lost the key they depend on. Found while capturing output for the README.

**The invariant test itself had to be corrected.** It forbade smart quotes everywhere, and
Bridge's lyrics spell *daffodils'* with a typographic apostrophe while Smyth's credit carries
an en dash. Rewriting either would be editing what the file says. The deny-list is now split:
music glyphs and zero-width characters are forbidden **everywhere**, typographic punctuation
only in the words Magnificat itself writes. Provenance is checked structurally — every
non-ASCII character in a transcript must appear in something the file supplied — rather than
guessed from the line, because at per-measure density one line holds both.

**Lesson, for whoever is next.** The unit tests were not wrong; they were complete for what
they described. What they could not do is notice that the *whole* was odd — a doubled heading,
an invisible character, a dangling parenthesis. Reading the output found seven things that
1,000 assertions did not. Keep the review requirement.

**State.** 196 tests green, 98.2% line coverage, README complete, CLI working.

---

### 24 August 2026 — Stopped guessing at keys

**Goal.** The user asked, after the library was otherwise complete: does MusicXML ever
actually name a key, and if so use it — but never guess one.

**What happened.** Surveyed all 92 `<key>` elements across the 31 fixtures before touching
any code. `<mode>` is present on **3 of them**. Two of those three are `<mode>none</mode>`, on
the Webern — the file stating outright that the music is atonal. The old rule, added on 23
August without checking this, filled every absent mode with the major tonic for the
accidental count. That is a guess presented as fact, and on real fixtures it was frequently
wrong: the Brahms carries one sharp and is in E minor; the rule called it G major. On the
Webern it was worse than wrong — it overrode the file's own explicit "no key" with `C major`.

**Decision.** The key is now named only when the file names it:

- `<mode>` is `major` or `minor` → `Key: E minor, 1 sharp, F sharp`.
- `<mode>` is something else (`dorian`, `mixolydian`, …) → the mode is spoken with no
  invented tonic: `dorian, no sharps or flats`.
- `<mode>` is `none` → `No key signature.`, the file's own claim.
- `<mode>` is absent (the common case — 89 of 92) → no tonic asserted at all. The line
  becomes `Key signature: <accidentals>`, and the accidentals now name **which notes are
  altered**, not just the count: `4 flats, B flat, E flat, A flat, D flat`. That is a fact
  regardless of mode and tells a player more than a guessed name would.

**Surprise.** None on the code side — this was checking an assumption, not discovering a
bug in working code. The interesting part is that the old rule passed every test and every
golden review without anyone noticing it was guessing, because a plausible major key *looks*
right sitting next to four flats. It took the user asking a direct question about the data to
surface it. Recorded as a lesson: a rule that fills a gap with an inference is worth
re-examining even after it ships clean, especially where the inference reads as confident
fact to someone who cannot check it — which is this library's whole risk surface.

**State.** `SPEC.md` §6.13, `Sources/Magnificat/KeySignature.swift` and `Heading.swift`
updated; all 49 goldens regenerated and reviewed for scope (confirmed only `Key`/`No key`
lines changed, nothing else moved); `README.md`'s captured CLI output and `SPEC.md` §7.5's
worked example updated to match. 201 tests green.
