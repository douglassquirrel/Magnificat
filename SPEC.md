# Magnificat — Library Specification

Status: **settled — ready to build against.** Written 23 August 2026 against the 31 real
MusicXML files now in `Tests/MagnificatTests/Fixtures/`: twelve hand-made CC0 voice-and-piano
transcriptions from the OpenScore Lieder Corpus, and nineteen machine-generated files from
KunstDerFuge's OMR work, which are what the real pipeline will actually feed this library.

Every decision is recorded in §14 with a pointer to the section that governs it. **§14 is
empty of open questions**; where something was deferred rather than decided, §14 says so and
says where the work would start.

`CLAUDE.md` covers **how** this gets built. `docs/validation-experiment.md` records the one
experiment run while writing this, which settled §6.15.

---

## 1. Name and one-line summary

- **Name:** Magnificat *(SwiftPM targets: `Magnificat`, `MagnificatCLI`, `MagnificatTests`)*
- **Summary:** Converts MusicXML into linear plain-text instructions that a blind or
  low-vision musician can read with a screen reader, a braille display, or enlarged text.

## 2. Purpose and motivation

Sheet music is a two-dimensional notation. Everything about it — a chord stacked
vertically, a piano's two staves read simultaneously, a dynamic marking floating below the
notes it governs — assumes an eye that can take in a page at once. A musician who cannot
read that page has, in practice, three options: braille music, which is a fluent and
complete notation but one that comparatively few people read; someone willing to describe
the score aloud; or learning entirely by ear. Magnificat adds a fourth: an accurate,
navigable, plain-text rendering of exactly what is on the page, produced on-device from a
MusicXML file, that any screen reader or refreshable braille display can already handle.

The output is deliberately *not* braille music. Braille music is a specialist skill with a
long learning curve. This library targets the much larger group who read ordinary text —
in speech or in literary braille — and who want to know what the notes are without having
to acquire a second notation first. The cost of that choice is verbosity; the benefit is
that it works today with the assistive technology people already own and already know.

It is a shared library rather than code inside each app because the two consuming apps
differ only in presentation. The rules for turning a `<note>` into the words "A flat 4,
dotted quarter" are intricate — key-signature and measure-local accidental state, divisions
arithmetic, backup and forward, multiple voices per staff — and getting them subtly wrong
produces confident, plausible, wrong instructions. That logic is worth writing once,
testing hard, and sharing. It is also the natural downstream half of a pair: `KunstDerFuge`
turns scanned pages into MusicXML; Magnificat turns MusicXML into something readable.

## 3. Consumers

- **iOS app:** loads a MusicXML file, transcribes it, and presents the transcript as
  VoiceOver-navigable text — the reader moves by line, measure, or part, and can extract a
  single vocal line to learn.
- **macOS app:** the same, plus exporting the transcript to a `.txt` file for a braille
  embosser or a refreshable display, and displaying it at large type sizes.
- **Command-line demo client:** proves the library works from outside an app. Transcribes a
  file to stdout, with flags for the main options, so the whole thing can be tried in ten
  seconds and piped into other tools.
- **Tests:** the same public API as the apps. No test-only entry points.

## 4. Core concepts and domain model

Two layers: a **parsed score** (faithful to the MusicXML, no English in it) and a
**transcript** (the English rendering). Keeping them apart is what makes the rendering
rules testable in isolation from XML parsing.

### Parsed score

```
Score
  metadata: ScoreMetadata
    workTitle, movementTitle, composer, lyricist, rights, encodingSoftware  (all optional)
  parts: [Part]

Part
  id: String                     // MusicXML "P1"
  name: String?                  // <part-name>, newlines collapsed to ", "
  staffCount: Int                // 1 for a vocal line, 2 for a piano grand staff
  measures: [Measure]

Measure
  number: String                 // MusicXML numbers are strings: "0", "1", "12a"
  isPickup: Bool                 // implicit="yes"
  attributes: MeasureAttributes? // only where the score restates them
    divisions, key (fifths, mode), time (beats/beatType, or nil = unmetered), clefs[]
  events: [MusicalEvent]         // in reading order, already resolved from backup/forward
  barline: Barline?              // repeat direction, ending numbers, bar style

MusicalEvent (enum)
  .note(Note)
  .rest(Rest)
  .direction(Direction)

Note
  pitch: Pitch                   // step, alter, octave
  printedAccidental: Accidental? // only when the score prints one
  duration: Duration             // divisions count + notated type + dots + tuplet ratio
  voice: Int
  staff: Int
  isChordMember: Bool            // <chord/> — sounds with the previous note
  tie: TieState?                 // .start, .stop, .startStop
  slur: SlurState?               // .start, .stop
  articulations: [Articulation]  // staccato, accent, tenuto, strong-accent, staccatissimo
  ornaments: [Ornament]          // trill, mordent, inverted mordent, wavy line
  fermata: Bool
  arpeggiate: Bool
  isGrace: Bool
  isCue: Bool
  lyrics: [Lyric]                // verse number, syllable text, syllabic position

Rest
  duration: Duration
  isWholeMeasure: Bool           // <rest measure="yes"/>
  voice, staff

Direction (enum)
  .dynamic(String)               // "p", "ff", "sf", ... rendered as words later
  .words(String)                 // "Un poco Adagio", "dolce"
  .metronome(beatUnit, dots, perMinute)
  .wedge(.crescendo | .diminuendo | .stop)
  .pedal(.start | .stop)
  .octaveShift(.up | .down | .stop, size)
  .rehearsal(String)
  .dashes(.start | .stop)
```

`Pitch` carries the written spelling (`step` + `alter` + `octave`). The **sounding pitch**
is a computed property that applies key signature and measure-local accidentals; the
renderer uses one or the other depending on `accidentalStyle`.

### Transcript

```
Transcript
  lines: [TranscriptLine]
  plainText: String              // lines joined with "\n", trailing newline
  anomalies: [Anomaly]           // musical incoherence found while rendering (§6.15);
                                 //   never fatal, empty for a clean file

Anomaly
  kind: .measureDurationMismatch | .staffOutOfRange | .voiceOutOfRange
      | .durationContradictsType | .backupBeforeMeasureStart | .missingMeasureInPart
  partID: String
  measureNumber: String
  detail: String                 // plain English, safe to show a user

TranscriptLine
  text: String                   // one self-contained line, no leading or trailing spaces
  kind: Kind                     // .scoreHeading .partHeading .measure .event .direction
                                 //   .lyricsSummary .blank
  partID: String?                // nil on score-level lines
  measureNumber: String?         // nil on lines not inside a measure
```

The structured form exists so a host app can build measure-by-measure navigation, jump to
a part, or highlight the current line, without re-parsing the text it just received.

## 5. Public API

### `Score.init(musicXML:)`

- **Purpose:** parse a MusicXML document into the domain model.
- **Inputs:** `Data` containing an uncompressed MusicXML file. UTF-8 or UTF-16, with or
  without a BOM; the encoding is taken from the XML declaration.
- **Output:** `Score`.
- **Errors:** `.malformedXML`, `.unsupportedRootElement`, `.unsupportedFormat`,
  `.emptyScore`, `.invalidValue`. See §6.16 for the full enum. A duration that cannot be
  expressed in the prevailing divisions is **not** an error (§6.3).
- **Notes:** throwing, synchronous, no I/O, no network. `Score` is `Sendable` and
  `Equatable`. Parsing never resolves external entities or fetches the DTD (see §10).

### `Score.summary`

- **Purpose:** cheap metadata for a file picker or a "what is this?" screen, without
  rendering a transcript.
- **Inputs:** none (computed property).
- **Output:** `ScoreSummary` — title, composer, lyricist, part names, measure count,
  opening key, opening time signature, whether lyrics are present and how many verses.
- **Errors:** none.

### `Score.transcript(options:)`

- **Purpose:** render the whole score as a transcript.
- **Inputs:** `TranscriptOptions` (defaulted, see section 6).
- **Output:** `Transcript`.
- **Errors:** none — any score that parsed can be rendered.
- **Notes:** pure function of `(Score, TranscriptOptions)`. Same input, same output, always.

### `Score.transcript(options:parts:measures:)`

- **Purpose:** render a subset — one singer's line, or bars 40 to 56 for practice.
- **Inputs:** `parts: [PartSelector]?` (`nil` = all); `measures: ClosedRange<Int>?`
  (`nil` = all), matched against measure numbers as printed.
- `PartSelector` is `.index(Int)` (1-based, document order) or `.named(String)` (matched
  against `<part-name>`, then against the part ID). **Selection by index must exist**: OMR
  output gives parts blank names and 32-character hash IDs, so a name or ID is often no
  handle at all.
- **Output:** `Transcript`.
- **Errors:** `.unknownPart(String)`, `.measureRangeOutOfBounds(requested:available:)`.

### `transcribe(musicXML:options:)`

- **Purpose:** the one-call convenience — `Data` in, `String` out.
- **Inputs:** as above.
- **Output:** `String`.
- **Errors:** as `Score.init(musicXML:)`.
- **Notes:** exactly equivalent to `try Score(musicXML:).transcript(options:).plainText`.

### `TranscriptOptions`

A `Sendable`, `Equatable` value with three knobs, all defaulted:

| Option | Values | Default | Why it exists |
| --- | --- | --- | --- |
| `layout` | `.byPart`, `.byMeasure` | `.byPart` | Learning your own line vs. following how the parts fit together. |
| `density` | `.perMeasure`, `.perEvent` | `.perMeasure` | Continuous reading in speech vs. line-by-line navigation on a braille display. |
| `accidentalStyle` | `.sounding`, `.asPrinted` | `.sounding` | Say the pitch to play, vs. say what is printed on the page. |

## 6. Behavior and rules

### 6.1 Vocabulary — the hard constraint

Output is **plain text and nothing else**. Concretely, and this is testable:

- Every character in the *musical vocabulary* is ASCII. The word `flat`, never a flat sign;
  `sharp`, never a sharp sign; `natural`, never a natural sign. No musical symbols, no
  emoji, no arrows, no box drawing, no bullet characters, no em dashes, no smart quotes.
- **Lyric text passes through unchanged**, including non-ASCII — the corpus is German and
  French, and `Blüthe` must stay `Blüthe`. Lyrics are the only place non-ASCII may appear.
- **No layout.** No column alignment, no padding spaces, no ASCII tables, no indentation
  used to convey meaning. Screen readers and braille displays handle these badly. Every
  line stands alone and is meaningful when read out of context.
- **No quotation marks around lyrics.** Many screen readers announce them. Lyrics are
  introduced by the word `lyric` (per-measure) or a `Lyric:` prefix (per-event) instead.
- Lines are separated by `\n`, never `\r\n`. No trailing whitespace on any line. No blank
  line at the start; exactly one trailing newline at the end.

### 6.2 Note names

- Step letter, then accidental word if any, then octave number: `A flat 4`, `F sharp 3`,
  `B natural 4`, `C 5`. Octave numbering is scientific — **octave 4 begins at middle C** —
  which coincides with braille music's octave numbering, so a reader who knows either is
  not surprised. The octave number is stated on **every** note, including a repeat of the
  preceding pitch; it is never dropped as understood.
- **A repeated pitch is spelled out in full every time.** Eight repeated A flats produce
  `A flat 4` eight times. This is more to listen to, and it is deliberate: an abbreviation
  such as `same` gives a reader nothing to re-synchronise against if they lose their place
  mid-measure, and the whole value of the transcript is that any line can be trusted on its
  own.
- Double accidentals are `double flat` / `double sharp` (`alter` of -2 or +2).
- Under `accidentalStyle: .sounding` (default) the accidental word reflects the pitch that
  sounds, whether it comes from the key signature, a measure-local accidental, or is
  printed on the note. In A flat major, a plain `E` note reads `E flat 4`.
- Under `.asPrinted`, the accidental word appears only where the score prints an
  `<accidental>`. The same note reads `E 4`, and the reader is expected to apply the key
  signature themselves, as a sighted reader does.
- Accidental state is measure-local and voice-independent: an accidental applies to that
  step and octave for the rest of the measure, across all voices and staves of that part,
  and is cancelled by the next barline. A note tied across a barline keeps its accidental.

### 6.3 Durations

- `whole`, `half`, `quarter`, `eighth`, `sixteenth`, `thirty-second`, `sixty-fourth`,
  `breve`. American names only — British names (crotchet, quaver) are a non-goal, decided
  23 August 2026, so there is no option and no lookup table for them.
- Dots prefix the name: `dotted quarter`, `double dotted half`.
- Tuplets are named where the ratio is recognisable — `triplet eighth`, `quintuplet
  sixteenth` — and stated as a ratio otherwise: `7 in the time of 4, sixteenth`.
- The notated `<type>` is authoritative for the name. `<duration>` in divisions is used for
  timing arithmetic (chord alignment, backup, measure completeness) and is never spoken.
- A `<note>` with no `<type>` — legal, and it happens — gets its name inferred from
  `<duration>` and the prevailing `<divisions>`. If that inference does not land on a
  representable value, the transcript says `duration <n> divisions` rather than guessing.

### 6.4 Rests

- `Whole measure rest` for `<rest measure="yes"/>`, whatever the time signature.
- Otherwise the duration name plus `rest`: `Quarter rest`, `Dotted eighth rest`.
- Consecutive whole-measure rests in the same part collapse: `Measures 1 to 3. Rest.`
  A single one is `Measure 1. Whole measure rest.`

### 6.5 Chords

MusicXML marks the second and later notes of a chord with `<chord/>`. These are gathered
into one event and rendered **low to high** regardless of document order:

- Per-measure density: `Chord A flat 4, A flat 5, dotted quarter.`
- Per-event density: one line, `Chord: A flat 4, A flat 5. Dotted quarter.`

Ordering low-to-high is a deliberate choice: it matches how a keyboard player thinks about
a shape under the hand, and it makes two occurrences of the same chord read identically
even when the exporter ordered the notes differently.

### 6.6 Parts, staves, and voices

- A one-staff part is rendered as a single stream and labelled by its part name: `Voice`.
- A two-staff part is a grand staff. Staff 1 is `Right hand`, staff 2 is `Left hand`, and
  the two are rendered as separate streams so each hand can be learned alone.
- **Hands are labelled only where the file says a part has two staves.** Machine-generated
  MusicXML routinely splits a grand staff into two separate one-staff parts (see
  `Tests/MagnificatTests/Fixtures/omr-output/`), and nothing in the file reliably marks the
  pair as one instrument. Magnificat does not guess: two one-staff parts are two parts. A
  wrong `Left hand` label is worse than an unglamorous `Part 2`, because the reader has no
  way to catch it.
- **Part naming falls back by position.** `<part-name>` is used when it is present and not
  blank; otherwise the stream is `Part 1`, `Part 2`, numbered by document order. Blank part
  names are the norm in machine output, so this is the common path, not an edge case.
- Where a staff carries more than one voice — common in piano writing, and present in this
  corpus as voices 1 and 2 on staff 1, 5 and 6 on staff 2 — each voice is a separate
  stream, labelled `voice 2` and so on. Voice 1 of a staff is not labelled; a lone voice
  never needs a number.
- **A stream renders only the measures it actually sounds in.** A secondary voice
  is silent for most of a part — the Mayer's vocal line has seven notes in voice 2
  across 32 measures — and a bare `Measure 4.` with nothing after it says nothing
  while making a reader step through dozens of empty lines. Added 23 August 2026
  while building §7.1, which the empty lines broke.
- `<backup>` and `<forward>` are resolved during parsing. They never appear in the output;
  their only job is to place events on the right staff and voice at the right time.
- Parts appear in document order. Part names come from `<part-name>`, with embedded
  newlines collapsed to `, ` — the corpus contains `Singstimme\nVoice`, which becomes
  `Singstimme, Voice`.
- **Any number of parts is supported.** The corpus runs from 1 part to 5 (SATB plus piano);
  each is transcribed in turn by the same generic path. Voice and piano is the case that
  motivated the library, not a limit it enforces.
- `<voice>` and `<staff>` are **optional in practice** and default to 1 when absent. In the
  OMR fixtures 3,317 of 6,494 notes carry no `<voice>` and 6,170 carry no `<staff>`; a
  parser that requires either would reject most real machine output.

### 6.7 Layout

**`.byPart`** — the whole of one part, then the whole of the next. Within a two-staff part,
the whole of the right hand, then the whole of the left hand. This is the default because
the commonest task is learning one line.

**`.byMeasure`** — measure 1 of every stream, then measure 2 of every stream. This is for
working out how the parts fit together, and for accompanists.

**Absent measures are announced.** OMR output is frequently ragged — one part stops several
bars before another — so under `.byMeasure` a stream that has no such measure produces
`Part 2 has no measure 37.` rather than being silently skipped. Silence would read as a bar of
rest, which is a different piece of music. Each announcement also records a
`.missingMeasureInPart` anomaly (§6.15).

### 6.8 Density

**`.perMeasure`** — one line per measure. Events are separated by `. ` and the line begins
with `Measure <n>. `. Best for continuous reading.

**`.perEvent`** — a `Measure <n>` line, then one line per event. Best for a braille display,
and for arrow-key navigation note by note.

### 6.9 Directions

Directions are rendered where they occur in the event stream, before the note they precede.

- Dynamics are spelled as words and always prefixed: `Dynamic: piano`, `Dynamic: fortissimo`,
  `Dynamic: sforzando`. The prefix is not decoration — without it, `Piano` at the start of a
  line is ambiguous between the instrument and the dynamic, which is exactly the kind of
  quiet wrongness this library exists to avoid.
- Wedges: `Crescendo begins`, `Diminuendo begins`, `Crescendo ends`. The word matches the
  wedge that is stopping.
- `<words>` pass through as written, on their own: `Un poco Adagio`, `dolce`.
- `<metronome>`: `Tempo: quarter note equals 71.` Where only a `<sound tempo="...">` is
  present, it is ignored — it is playback data, not notation.
- Pedal: `Pedal down`, `Pedal up`. Octave shift: `Octave shift down begins`, `Octave shift
  ends`. Rehearsal marks: `Rehearsal mark A`.

### 6.10 Notations attached to notes

Appended to the note, in this fixed order, each introduced by a comma: tie, slur,
articulations (in document order), ornament, arpeggio, fermata, then lyrics.

`A flat 4, dotted quarter, tied, staccato, lyric bist`

- Ties: `tied` on the first note of a tie, `tied from previous` on the continuation. The
  continuation note is still spoken — a reader needs to know a sound is still going.
- Slurs: `slur begins`, `slur ends`. A note that both ends one slur and begins another says
  both, in that order.
- Grace notes are prefixed rather than suffixed: `Grace note: B flat 4, eighth.`
- Cue notes are prefixed `Cue note:` and are otherwise rendered normally.
- Articulations use their plain names: `staccato`, `staccatissimo`, `accent`, `tenuto`,
  `marcato` (for `strong-accent`), `breath mark`.
- Ornaments: `trill`, `mordent`, `inverted mordent`. Ornaments are named, never realised
  into notes.

### 6.11 Lyrics

- A syllable is attached to its note. Hyphenation follows `<syllabic>`: `begin` and
  `middle` get a trailing hyphen, `end` and `middle` a leading one, `single` neither. So
  `Blu` + `me` reads `lyric Blu-` then `lyric -me`, and a reader knows the word continues.
- Verses beyond the first are numbered: `verse 2 lyric ...`. The corpus goes up to three.
- `<extend>` (a melisma) reads `lyric continues` on the notes it covers.
- After each part that has lyrics, a `.lyricsSummary` block gives each verse as continuous
  running text with syllables joined into words, so the text can be read as text.

### 6.12 Measures, barlines, and repeats

- Measure numbers are the ones printed in the score, as strings. A pickup measure
  (`implicit="yes"`, numbered `0` in this corpus) is announced as `Pickup measure.`
- Repeats: `Repeat: go back to the start of measure <n>.` for a backward repeat, resolved
  to the matching forward repeat or to the start of the piece. `Repeat: forward repeat
  begins here.` for the forward mark.
- Endings: `First ending begins.`, `Second ending begins.`, `Ending finishes.`
- Double barlines and final barlines: `Double barline.`, `Final barline.`

### 6.13 Score heading

Every transcript opens with a heading block, one fact per line, omitting what the file does
not carry:

```
Du bist wie eine Blume
Emilie Mayer
Words by Heinrich Heine
From 3 Lieder, Opus 7, number 1
2 parts: Singstimme, Voice; Pianoforte
32 measures
Key: A flat major, 4 flats
Time signature: 4 4
```

- The key is named from `<fifths>` and `<mode>`. Where `<mode>` is absent, the major name is
  given with the accidental count, which is unambiguous and does not assert a mode the file
  did not state.
- A time signature is written as its two numbers with a space between and never a solidus:
  `Time signature: 4 4`, `Time signature: 3 4`, `Time signature: 6 8`. The label always
  precedes it, so the bare pair of numbers is never left to be guessed at. Screen readers
  read a solidus aloud as "slash".
- `symbol="common"` and `symbol="cut"` are printed glyphs, not different meters; they are
  rendered as `4 4` and `2 2`.
- Where a score has no `<time>` at all — the Parry in the corpus has none — the line reads
  `No time signature.` rather than being omitted, because its absence is information.
- Key and time changes mid-piece are announced in the measure where they occur:
  `Key changes to E major, 4 sharps.`, `Time signature changes to 3 4.`

### 6.14 Parsing rules

- `<score-partwise>` only. `<score-timewise>` throws `.unsupportedRootElement` — it is
  legal MusicXML, it is vanishingly rare in the wild, and silently mishandling it would be
  worse than refusing it.
- **The DOCTYPE is optional.** Where present it is accepted and ignored; where absent the
  file is parsed exactly the same way. Eight of the nineteen machine-generated fixtures have
  no DOCTYPE, so requiring one would reject most of the output of the tool immediately
  upstream of this library. The root element, not the DOCTYPE, decides whether a file is
  MusicXML.
- **External entities are never resolved and the DTD is never fetched.** A file that parses
  must never cause a network request.
- The `version` attribute is read but not enforced. MusicXML 3.x and 4.x are both in the
  fixtures (3.1 and 4.0); nothing branches on the version.
- `<divisions>` may be restated; the current value applies from where it appears. A
  `<duration>` that cannot be expressed in the prevailing divisions is not an error — see
  §6.3.
- Unknown elements are skipped without error. MusicXML is large, exporters emit vendor
  extensions, and refusing to read a file because of a `<credit-image>` would be useless
  behaviour.
- Print and layout elements (`<print>`, `<defaults>`, positions, fonts, `<stem>`,
  `<beam>`, `<notehead>`) are parsed as far as skipping them requires and never rendered.
  They describe how the page looks, and the page is exactly what this reader cannot see.

### 6.15 Validation

Settled 23 August 2026 by experiment; the measurements are below and are reproducible.

**Can a file with no DOCTYPE be validated? Yes.** A DOCTYPE is only a *pointer* to a schema.
Validating needs the schema itself, and Magnificat would supply its own bundled copy rather
than trusting the document to name one. All 31 fixtures validate against the MusicXML 4.0
XSD with the network disabled, including all 9 that carry no DOCTYPE. The missing DOCTYPE is
a non-issue.

**Should we validate? Not for now — decided 23 August 2026.** Schema validation was measured
against seven deliberately corrupted copies of `mayer-1-du-bist-wie-eine-blume.musicxml`:

| Corruption | Schema verdict |
| --- | --- |
| Every octave shifted down by one — the whole song in the wrong register | **passes** |
| Measure 5 short by a beat — the bar no longer adds up | **passes** |
| `<duration>999</duration>` on a note typed `quarter` | **passes** |
| Every E flat respelled as E double-sharp | **passes** |
| A note on staff 7 of a two-staff part | **passes** |
| `<octave>banana</octave>` | rejected |
| Not well-formed XML | rejected |

Five of the seven pass, and those five are precisely the corruptions that would produce a
confident, plausible, wrong transcript — the failure mode this library exists to prevent. The
two it catches are both failures Magnificat's own parser must detect anyway: it cannot build a
`Pitch` from `banana`, and `XMLParser` stops on ill-formed input by itself. **Schema validation
therefore adds no safety this library does not already have, at the cost of a C-interop
dependency and a bundled 387 KB schema set.**

This is the same conclusion KunstDerFuge reached from the other end, on output rather than
input: *"Schema validity is useless here. Every run validates, including the 23.8% one.
Malformed output and wrong output are different failures, and only the first is what
validation catches."* (`../KunstDerFuge/docs/prototype-results.md`).

**What Magnificat does instead** — musical coherence checks, which the schema cannot express
and which map directly onto what a reader would be misled by:

- Each measure's voices are checked against the prevailing time signature, and a measure whose
  durations do not add up is reported.
- `<staff>` and `<voice>` references outside the part's declared staves are reported.
- A `<duration>` that contradicts its `<type>` under the prevailing `<divisions>` is reported.
- A `<backup>` that would move before the start of the measure is reported.

**These are reported, never fatal.** Every one of them occurs in real OMR output, and a reader
whose scanned page produced a ragged bar still wants the transcript — with a warning, not a
refusal. Anomalies are surfaced as `Transcript.anomalies: [Anomaly]`, each carrying its part
and measure, and the transcript is still produced. Only the errors in §6.16 stop the work.

**This is deferred, not ruled out forever.** If a reason to validate appears — a new exporter
producing files this parser mishandles, or a caller who needs a formal conformance statement —
the groundwork below is done and the decision can be revisited without new research. What must
not happen is validation drifting in as a vague reassurance: it buys the safety measured in the
table above and no more.

**How it would be done**, proven to build for iOS:
`XMLDocument` — Foundation's validating API — **does not exist on iOS** (confirmed by
compiling against the iOS 26.5 SDK), but **libxml2 is in the iOS SDK** with `xmlschemas.h`, a
modulemap and a linkable stub, and a Swift `xmlSchemaValidateDoc` call compiles clean for
`arm64-apple-ios16.0` and gives verdicts identical to `xmllint`. It would have to live in a
**separate target**, not in `Sources/Magnificat/`, which stays Foundation-only per `CLAUDE.md`.
Two packaging traps, both already paid for by KunstDerFuge: `musicxml.xsd` hardcodes remote
`schemaLocation` imports that must be rewritten to local paths or schema compilation fails
outright, and the DOCTYPE must not be resolved or libxml2 will fetch `musicxml.org` — a silent
network request in a library that promises never to make one.

### 6.16 Errors

`public enum TranscriptionError: Error, Equatable`. These stop the work; the coherence
problems in §6.15 do not.


| Case | Provoked by | What the caller should do |
| --- | --- | --- |
| `.malformedXML(line: Int, message: String)` | not well-formed XML | report the position to the user |
| `.unsupportedRootElement(found: String)` | `<score-timewise>`, or not a score at all | ask for a partwise export |
| `.unsupportedFormat(String)` | a compressed `.mxl` (detected by its zip signature) | uncompress it first |
| `.emptyScore` | no parts, or every part has no measures | the file has no music in it |
| `.invalidValue(element: String, value: String)` | `<octave>x</octave>`, `<fifths>12</fifths>` | the file is corrupt |
| `.unknownPart(String)` | a part ID or name not in the score | offer the real part names |
| `.measureRangeOutOfBounds(requested: ClosedRange<Int>, available: ClosedRange<Int>)` | asking for bars 90 to 100 of a 64-bar song | clamp or re-ask |

Every case is provoked by at least one test.

## 7. Worked examples

Exact expected output. These become tests verbatim. Input is
`mayer-1-du-bist-wie-eine-blume.musicxml` (A flat major, common time, voice and piano), all
defaults unless stated.

### 7.1 Voice part, measures 4 to 6, defaults (`.byPart`, `.perMeasure`, `.sounding`)

```
Measure 4. Half rest. Quarter rest. Dynamic: piano. E flat 4, quarter, lyric Du.
Measure 5. A flat 4, dotted quarter, lyric bist. A flat 4, eighth, lyric wie. A flat 4, quarter, lyric ei-. A natural 4, quarter, lyric -ne.
Measure 6. C 5, quarter, lyric Blu-. B flat 4, quarter, lyric -me. Quarter rest. B flat 4, eighth, lyric so. A flat 4, eighth.
```

### 7.2 The same measure 5, `density: .perEvent`

```
Measure 5
A flat 4, dotted quarter
Lyric: bist
A flat 4, eighth
Lyric: wie
A flat 4, quarter
Lyric: ei-
A natural 4, quarter
Lyric: -ne
```

### 7.3 The same measure 5, `accidentalStyle: .asPrinted`

Only the fourth note carries a printed accidental; the flats come from the key signature.

```
Measure 5. A 4, dotted quarter, lyric bist. A 4, eighth, lyric wie. A 4, quarter, lyric ei-. A natural 4, quarter, lyric -ne.
```

### 7.4 Piano part, right hand, measure 1, defaults

Staff 1 voice 1 is a chord of A flat 4 and A flat 5 repeated four times, the last pair
naturalised.

```
Right hand
Measure 1. Chord A flat 4, A flat 5, dotted quarter. Chord A flat 4, A flat 5, eighth. Chord A flat 4, A flat 5, quarter. Chord A natural 4, A natural 5, quarter.
```

### 7.5 Score heading for the same file

As printed in section 6.13.

### 7.6 A score with no time signature

`parry-2-good-night.musicxml` has no `<time>` element anywhere. Its heading contains the
line `No time signature.` and it transcribes without error.

### 7.7 Golden transcripts for every fixture

The examples above are hand-written and exact, and they pin down the rules. They are not
enough on their own: they cover a handful of measures of one file, and a change to, say,
accidental state could leave all six passing while silently wrecking the other thirty files.

**Every fixture in `Tests/MagnificatTests/Fixtures/` has a checked-in expected transcript, and
a test asserts that the fixture still produces it, byte for byte.**

- Goldens live in `Tests/MagnificatTests/Golden/`, mirroring the fixture directory structure,
  one `.txt` per fixture at **default options**.
- A chosen subset — Mayer, Parry, Webern, Davies, and two OMR files including one with a split
  grand staff — additionally has a golden for **each non-default option**: `.byMeasure`,
  `.perEvent`, `.asPrinted`. Every option must appear in at least one golden of every kind of
  input, and no option may go untested.
- The test failure message shows a **unified diff** of expected against actual, trimmed to the
  differing lines. A golden diff that runs to hundreds of lines is useless for diagnosis.

**A golden is a reviewed artefact, not a recording of what the code did.** This is where golden
testing usually goes wrong and where `CLAUDE.md`'s rule against editing tests to match
unexpected output bites hardest:

- There is **no regenerate-all flag**. Regeneration in bulk turns every golden into a
  restatement of current behaviour, which asserts nothing.
- When a change alters a golden, the diff is **read, and the change is justified in the report
  to the user** before the new text is committed — naming which rule in §6 produced the change.
  An unexplained golden diff is a failed step, exactly like an unexplained red test.
- A golden may only be created for a fixture whose transcript has been **read through at least
  once** by a person. An unreviewed golden pins down a bug just as firmly as it pins down
  correct behaviour.

**All 31 fixtures get a golden, and all 31 get reviewed** — confirmed 23 August 2026, in
preference to a smaller set. The review is proportionate to length, and this is the agreed
protocol rather than a corner cut:

- **Short fixtures** — under about 60 measures, which is most of them — are read in full.
- **Long fixtures** — the 252-bar Beethoven, the 222-bar Smyth, the 220-bar Satie, the 208-bar
  Joplin, the 182-bar Chabrier — are read for the **first and last twenty measures**, plus
  **every measure that carries an anomaly** (§6.15), which is where incoherent input surfaces
  and where a rendering bug is most likely to show.
- A fixture is not marked reviewed until that reading has happened. Which fixtures have been
  reviewed, and to which depth, is recorded in `Tests/MagnificatTests/Golden/README.md` so the
  state survives a change of session.

The goldens have a second job beyond regression. They are the only artefact in this project
that a blind musician can actually assess: someone who knows *Du bist wie eine Blume* can read
its transcript and say whether it describes the song. That review is worth more than any
assertion in the suite, and the goldens are what make it possible to ask for.

### 7.8 Invariants over the whole golden corpus

Separately from the byte-for-byte comparison, one property test runs over **every line of every
golden** and asserts the §6.1 rules, which no individual example can guarantee:

- Every character outside a lyric or a title is ASCII.
- No line has trailing whitespace; no line contains a tab or any C0 control character.
- No `\r` anywhere; the file ends with exactly one `\n`.
- No line is empty except where a `.blank` line is intended by the layout.
- No musical symbol, emoji, smart quote, em dash, or box-drawing character appears anywhere —
  asserted as an explicit deny-list, so a new one cannot creep in through a new rule.
- Every line that mentions a measure names a measure number that exists in the source file.

This is the test that would catch a flat sign leaking into the output through a code path
nobody thought about, which is the single most likely way this library fails its users.

## 8. Data, persistence, and formats

The library performs **no I/O at all**. It takes `Data` in and returns values. It does not
read files, write files, touch the network, or cache anything. Opening the file is the host
app's job, and the CLI's.

- **Input format:** uncompressed MusicXML, partwise, versions 3.x and 4.x, with or without
  a DOCTYPE (§6.14). Both exporters in the fixtures — MuseScore 4.5.2 and music21 v10.5.0 —
  must work, and neither is special-cased. Files need only be well-formed XML that a
  MusicXML reader can make sense of. **Files are not validated against the DTD or the XSD**
  — §6.15 records the experiment behind that decision, and the coherence checks that replace
  it.
- **Output format:** UTF-8 plain text, `\n` line endings. Not `Codable`, not versioned — it
  is prose for a person, not a wire format.
- `Score` and `Transcript` are `Equatable` for testing but deliberately **not** `Codable`.
  Nothing in the design calls for persisting them, and a serialisation format is a
  compatibility promise that should not be made speculatively.

## 9. Platform boundaries

**None.** This is the useful consequence of section 8: the library is a pure function from
`Data` to text, so there is nothing platform-specific to inject — no file system, no
keychain, no network, no notifications, no clock, no UUIDs, no randomness. There are no
protocols for the host app to implement and no defaults to override, and every test is
hermetic without effort.

One portability constraint follows from this and matters at implementation time:
**`XMLDocument` is macOS-only. Use `XMLParser`**, which is in Foundation on every platform.
Reaching for the DOM API would compile on the Mac and break the iOS build.

## 10. Non-functional requirements

- **Performance:** the largest file in the corpus is 692 KB, 222 measures, roughly 1,600
  notes. Parse plus full transcript must complete in well under one second on an iPhone of
  the minimum supported vintage. Memory stays proportional to the score — parsing is
  streaming (`XMLParser` is SAX), and the whole document is never held as a DOM.
- **Concurrency:** all public types are value types and `Sendable`. There is no shared
  mutable state and no singleton, so any number of scores may be parsed and rendered
  concurrently. Tested under concurrent access.
- **Memory:** no hard cap. A pathological file is the caller's problem to size before
  passing it in.
- **Localisation / Unicode:** the musical vocabulary is English and ASCII only; localising
  it is a non-goal (§13). Lyric and title text is arbitrary Unicode and is passed through
  byte-for-byte, with no normalisation, case folding, or transliteration applied.
- **Accessibility / privacy:** accessibility *is* the product; §6.1 is the binding
  constraint on all output. On privacy: the library logs nothing, and a score can be
  unpublished work, so it must never be transmitted anywhere — reinforced by there being no
  networking code at all.
- **Security:** external entity resolution stays off. An untrusted MusicXML file must not be
  able to make the library read a local file or open a connection.

## 11. Platform and toolchain targets

- Minimum iOS version: **16.0**
- Minimum macOS version: **13.0**
- swift-tools-version: **5.10**, as `CLAUDE.md` specifies. The installed toolchain is Swift
  6.3.3, so the test suite uses **Swift Testing** (`import Testing`, `@Test`, `#expect`) per
  `CLAUDE.md`. Language features newer than 5.10 are not used in the library source.
- Third-party dependencies: **none.** `XMLParser` from Foundation covers parsing, and the
  CLI parses its own arguments from `CommandLine.arguments`.

## 12. CLI client scope

```
magnificat <file.musicxml> [options]

  --info                    print the score heading only and exit
  --part <n-or-name>        restrict to one part, by 1-based position or by name
                            (repeatable; position works on unnamed parts)
  --parts                   list the parts with their positions and names, and exit
  --measures <a>-<b>        restrict to a measure range
  --layout by-part|by-measure          (default: by-part)
  --density per-measure|per-event      (default: per-measure)
  --accidentals sounding|as-printed    (default: sounding)
  --help
```

Transcript to stdout, errors to stderr, exit `0` on success and non-zero on failure, with
distinct codes for "could not read the file" and "could not transcribe it". Example
session:

```
$ magnificat mayer-1-du-bist-wie-eine-blume.musicxml --part Voice --measures 4-5
Measure 4. Half rest. Quarter rest. Dynamic: piano. E flat 4, quarter, lyric Du.
Measure 5. A flat 4, dotted quarter, lyric bist. A flat 4, eighth, lyric wie. A flat 4, quarter, lyric ei-. A natural 4, quarter, lyric -ne.
```

## 13. Explicit non-goals

- **Braille music.** Not braille music notation, not braille ASCII, not BRF. Plain text that
  a braille display renders in literary braille is the whole point.
- **Optical music recognition.** Getting MusicXML out of a scanned page is `KunstDerFuge`.
- **Compressed `.mxl`.** Detected and refused with a clear error, not unzipped. Adding a zip
  reader is a dependency or a large piece of new code for a format the user does not need.
- **Audio, MIDI, playback, or tempo maps.** Nothing here makes a sound.
- **Round-tripping.** The library never writes MusicXML and the transcript is not
  reversible.
- **Transposition, analysis, fingering, or realising ornaments and figured bass.** The
  transcript reports what is on the page; it does not interpret it.
- **Localisation of the musical vocabulary.** English only, and American duration names
  only — no crotchets or quavers, and no option for them.
- **Rendering, layout, or anything visual.** Including page and system breaks, which are
  discarded.
- **Schema validation inside the core library.** Measured and set aside in §6.15: it passes
  five of seven musical corruptions while costing a C dependency and a bundled schema. Deferred
  rather than ruled out — if it is ever wanted it goes in a separate target, never in
  `Sources/Magnificat/`.

## 14. Open questions

**None. The spec is settled and ready to build against.**

Decisions taken 23 August 2026, in the order they were made, each now written into the section
that governs it:

| Decision | Where it lives |
| --- | --- |
| American duration names; no British option | §6.3, §13 |
| `Time signature: 4 4` — the label always precedes it, never a solidus | §6.13 |
| `A flat 4`; the octave is stated on every note | §6.2 |
| `.perMeasure` density by default | §6.8 |
| Repeated pitches spelled out in full every time, never abbreviated | §6.2 |
| Any number of parts, 1 to 5, through one generic path | §6.6 |
| All 31 relevant MusicXML files copied in | `Tests/MagnificatTests/Fixtures/` |
| No warning when a file has no lyrics | — (rule dropped) |
| No inferred names for parts; a split grand staff is two parts | §6.6 |
| Strange metadata reflected verbatim, never edited | §6.13 |
| Absent measures announced, not silently skipped | §6.7 |
| Whole-measure rest runs collapse | §6.4 |
| `<sound tempo>` ignored when there is no `<metronome>` | §6.9 |
| **No schema validation for now**; coherence checks reported as anomalies instead | §6.15, §13 |
| **All 31 goldens written and all 31 reviewed**, at a depth proportionate to length | §7.7 |

Two things are deliberately deferred rather than undecided, and both are recorded where the
work would start:

- **Schema validation** (§6.15). The experiment is done, the iOS route is proven, and the
  decision can be revisited without new research if a reason appears.
- **Localisation of the musical vocabulary** (§13). English only, and nothing in the design
  forecloses it — but no `Lexicon` indirection is built speculatively for it either.

When something here turns out to be wrong in the building, change this file in the same commit
that discovers it, and say which decision moved and why.
