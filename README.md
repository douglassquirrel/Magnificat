# Magnificat

**Magnificat turns MusicXML into linear plain text that a blind or low-vision musician can
actually read** — with a screen reader, on a refreshable braille display, or as an enlarged
text file. Sheet music is a two-dimensional notation: a chord stacked vertically, a piano's
two staves read at once, a dynamic floating below the notes it governs. Magnificat unrolls
all of that into one thing after another, in words. It is deliberately **not** braille music
notation, which is a specialist skill with a long learning curve; it is ordinary English
prose, so it works today with the assistive technology people already own and already know.

```
Measure 4. Half rest. Quarter rest. Dynamic: piano. E flat 4, quarter, lyric Du.
Measure 5. A flat 4, dotted quarter, lyric bist. A flat 4, eighth, lyric wie. A flat 4, quarter, lyric ei-. A natural 4, quarter, lyric -ne.
```

The library is a portable Swift package with **no dependencies**, no I/O and no platform
code, so the same build runs unchanged in an iOS app, a macOS app, and the command-line
client that ships with it.

## Requirements

- **Swift 5.10** or newer (the package declares `swift-tools-version: 5.10`)
- **iOS 16** / **macOS 13** or newer
- No third-party dependencies

The test suite uses **Swift Testing**, which needs a Swift 6 toolchain to run. The library
itself does not.

## Installation

Swift Package Manager, in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/Magnificat.git", from: "1.0.0")
],
targets: [
    .target(name: "YourApp", dependencies: ["Magnificat"])
]
```

**In Xcode, for both an iOS and a macOS target:** *File ▸ Add Package Dependencies… ▸ Add
Local…*, choose this folder, and add the `Magnificat` library to each target under *General
▸ Frameworks and Libraries*. Because the library imports only `Foundation`, one copy serves
both; there is nothing to conditionally compile.

## Quick start

```swift
import Magnificat

let data = try Data(contentsOf: url)     // your app opens the file
let text = try transcribe(musicXML: data)
print(text)
```

That is the whole API for the common case. Everything below is refinement.

## Usage

### What is this file?

`summary` reads the metadata without rendering anything, which is what a file picker wants:

```swift
let score = try Score(musicXML: data)
let summary = score.summary

summary.title         // "Du bist wie eine Blume"
summary.composer      // "Emilie Mayer"
summary.partNames     // ["Singstimme, Voice", "Pianoforte"]
summary.measureCount  // 32
summary.hasLyrics     // true
```

### Just my line, bars 4 to 6

Parts can be picked by **position** as well as by name. Position matters: machine-generated
MusicXML — the kind an optical-recognition tool produces — routinely leaves parts unnamed
and gives them 32-character hash IDs, so a name is often no handle at all.

```swift
let score = try Score(musicXML: data)
let transcript = try score.transcript(parts: [.index(1)], measures: 4...6)
let lines = transcript.lines.filter { $0.kind == .measure }.map(\.text)
```

### One line per note, for a braille display

```swift
let options = TranscriptOptions(density: .perEvent)
let text = try Score(musicXML: data).transcript(options: options).plainText
```

```
Measure 5
A flat 4, dotted quarter
Lyric: bist
A flat 4, eighth
Lyric: wie
```

### The options, in full

| Option | Values | Default | What it changes |
| --- | --- | --- | --- |
| `layout` | `.byPart`, `.byMeasure` | `.byPart` | The whole of one line at a time, or measure 1 of every part then measure 2. The first is for learning your own line; the second for hearing how the parts fit. |
| `density` | `.perMeasure`, `.perEvent` | `.perMeasure` | One line per measure, or one per note. Per-measure reads more smoothly in speech; per-event navigates better with arrow keys and on a braille display. |
| `accidentalStyle` | `.sounding`, `.asPrinted` | `.sounding` | Say the pitch that sounds (`E flat 4`), or only the accidentals the page prints (`E 4`, leaving you to apply the key signature as a sighted reader does). |

### Structured lines, not just a string

`Transcript.lines` is an array of `TranscriptLine`, each carrying its `kind`, `partID` and
`measureNumber`. A host app can build measure-by-measure navigation, jump to a part, or
highlight the current line without re-parsing the text it was just given. `plainText` is
there when you only want the string.

### Warning a reader about a scruffy file

Magnificat checks musical coherence — overfull bars, notes on staves the part does not
declare, durations that contradict their notated type — and reports what it finds **without
refusing to transcribe**. Optical recognition produces incoherent MusicXML routinely, and a
reader whose scanned page produced a ragged bar still wants the transcript, with a warning
rather than a refusal.

```swift
let transcript = try Score(musicXML: data).transcript()
for anomaly in transcript.anomalies {
    print("Measure \(anomaly.measureNumber): \(anomaly.detail)")
}
```

Show these somewhere separate from the reading — the command-line client puts them on
`stderr` precisely so they cannot end up inside a braille export.

## Error handling

`TranscriptionError` has one case per distinct thing a caller can do something about:

| Case | What happened | What to do |
| --- | --- | --- |
| `.malformedXML(line:message:)` | Not well-formed XML | Show the position; the file is damaged |
| `.unsupportedRootElement(found:)` | `<score-timewise>`, or not a score at all | Ask for a partwise export |
| `.unsupportedFormat(_:)` | A compressed `.mxl` | Uncompress it first |
| `.emptyScore` | Parsed, but holds no music | Nothing to read |
| `.invalidValue(element:value:)` | e.g. `<octave>banana</octave>` | The file is corrupt |
| `.unknownPart(_:)` | No such part | Offer the real names from `summary.partNames` |
| `.measureRangeOutOfBounds(requested:available:)` | Bars 90–100 of a 32-bar song | Clamp, or re-ask |

```swift
do {
    return try transcribe(musicXML: data)
} catch TranscriptionError.unsupportedRootElement(let found) {
    return "Not a partwise score: found <\(found)>."
} catch TranscriptionError.unsupportedFormat(let what) {
    return "Magnificat does not read \(what)."
} catch TranscriptionError.malformedXML(let line, _) {
    return "Not well-formed XML, at line \(line)."
} catch TranscriptionError.emptyScore {
    return "That file holds no music."
}
```

Musical incoherence is **not** an error — it is an anomaly, and the transcript is produced
anyway. Only the cases above stop the work.

## Nothing to inject

The library takes `Data` and returns values. There is no file system, no network, no clock,
no randomness and no global state anywhere in it, so there are no protocols for a host app
to implement and no defaults to override. The same input always produces the same text, and
every test is hermetic without effort. Your app opens the file; Magnificat reads it.

The library is verified to compile for `arm64-apple-ios16.0` and the iOS simulator as well as
for macOS, so the portability claim is checked rather than assumed.

One consequence worth knowing if you extend it: **`XMLDocument` does not exist on iOS.**
Parsing uses `XMLParser`, which is in Foundation everywhere. External entity resolution is
switched off explicitly — a MusicXML DOCTYPE points at `musicxml.org`, and resolving it
would put a silent network request inside a library that promises never to make one.

## Command-line client

```bash
swift run MagnificatCLI --help
```

```
magnificat <file.musicxml> [options]

  --info                    print the score heading only and exit
  --part <n-or-name>        restrict to one part, by 1-based position or by
                            name (repeatable; position works on unnamed parts)
  --parts                   list the parts with their positions and names
  --measures <a>-<b>        restrict to a measure range, or <a> for one measure
  --layout by-part|by-measure          (default: by-part)
  --density per-measure|per-event      (default: per-measure)
  --accidentals sounding|as-printed    (default: sounding)
  --help                    print this and exit
```

The transcript goes to **stdout** and warnings and errors to **stderr**, so the transcript
can be redirected to a file on its own. Exit codes are distinct so a script can tell them
apart: `0` success, `2` bad usage, `3` could not read the file, `4` could not transcribe it.

```bash
$ magnificat mayer-1-du-bist-wie-eine-blume.musicxml --parts
1. Singstimme, Voice
2. Pianoforte
```

```bash
$ magnificat mayer-1-du-bist-wie-eine-blume.musicxml --info
Du bist wie eine Blume
Emilie Mayer
Words by Heinrich Heine
From 3 Lieder, Op.7, number 1
2 parts: Singstimme, Voice; Pianoforte
32 measures
Key: A flat major, 4 flats
Time signature: 4 4
```

```bash
$ magnificat mayer-1-du-bist-wie-eine-blume.musicxml --measures 1 --layout by-measure
(the heading, as above, then:)
Measure 1
Singstimme, Voice. Un poco Adagio. Whole measure rest.
Right hand. Chord A flat 4, A flat 5, dotted quarter. Chord A flat 4, A flat 5, eighth. Chord A flat 4, A flat 5, quarter. Chord A natural 4, A natural 5, quarter.
Left hand. A flat 3, eighth. C 4, eighth. E flat 4, eighth. C 4, eighth. C 3, eighth. E flat 3, eighth. G flat 3, eighth. E flat 3, eighth.
Left hand, voice 2. A flat 3, half. C 3, half.
```

## Testing

```bash
swift build
swift test --enable-code-coverage
swift run MagnificatCLI --help
```

**196 tests, all passing. Line coverage of the library target is 98.2%** (region coverage
93.1%). Every rule in `SPEC.md` §6 was written test-first: a failing test, run and watched
fail for the right reason, before the code that satisfies it.

The suite is in four layers, because each catches what the others miss:

1. **Unit tests** on hand-built values — pitch spelling, accidental state, durations.
2. **Parser tests** using small but *complete* `score-partwise` documents written inline, each
   provoking exactly one thing. Never fragments: a fragment is not XML and would prove nothing.
3. **Integration tests** over **31 real MusicXML files** — twelve hand-made CC0 transcriptions
   from the OpenScore Lieder Corpus, and nineteen files produced by optical music recognition,
   which are far scruffier and are what the real pipeline will hand this library. Note and
   measure counts are cross-checked against OpenScore's own manifest, which was computed
   independently of this library and so cannot drift to match it.
4. **49 golden transcripts**, compared byte for byte, plus a property test over every line of
   every golden asserting the plain-text rules — ASCII outside the file's own words, no tabs,
   no stray whitespace, and an explicit deny-list of musical symbols and emoji.

Reviewing those goldens found seven defects that every other test had passed, including a
music-font glyph smuggled into a `<words>` element as a Private Use codepoint and reaching
the transcript as an invisible character. `Tests/MagnificatTests/Golden/README.md` records
what was reviewed and how.

## Limitations and non-goals

- **Not braille music notation.** Plain text that a braille display renders in literary
  braille is the entire point.
- **Not optical music recognition.** Getting MusicXML out of a scanned page is a separate
  problem.
- **Compressed `.mxl` is refused**, with a clear error, rather than unzipped.
- **No audio, MIDI, playback or tempo maps.** Nothing here makes a sound.
- **No transposition, analysis, fingering, or realising ornaments.** Ornaments are named, never
  turned into notes. The transcript reports what is on the page; it does not interpret it.
- **English only**, and American duration names only — quarter and eighth, never crotchet and
  quaver. There is no option, deliberately.
- **Short bars are not reported as anomalies.** A short bar is routine in correct music — a
  pickup, the bar before a repeat, the bar closing a first ending — and telling a legitimate one
  from a defective one needs the repeat structure modelled. Only overfull bars are reported.
- **Optical recognition does not recover lyrics.** Every one of the nineteen machine-generated
  fixtures contains zero `<lyric>` elements. A singer working from a scanned page therefore
  gets the notes and none of the words. That is a limitation of what comes in, not of this
  library, but it is the one most likely to matter to the people this is for.
- **No blind or low-vision musician has yet read a word of this output.** Everything has been
  checked by eye, which is exactly the sense the output is designed not to need.
