# Does schema validation protect a blind reader?

Run 23 August 2026 to settle `SPEC.md` §6.15. Two questions were asked: whether MusicXML with
no DOCTYPE can be validated at all, and whether validating is worth doing.

## Method

The schema is the MusicXML 4.0 XSD, in the patched form KunstDerFuge already prepared at
`../KunstDerFuge/tools/prototype/schema/` — patched because `musicxml.xsd` hardcodes remote
`schemaLocation` imports for `xml.xsd` and `xlink.xsd`, and schema compilation fails outright
until those point at local paths. Validation ran with the network disabled throughout.

Seven corrupted copies of `mayer-1-du-bist-wie-eine-blume.musicxml` were generated, five of
them musically wrong but structurally ordinary, two of them structurally broken as controls.

## Result 1 — a missing DOCTYPE is no obstacle

All 31 fixtures validate, including the 9 that carry no DOCTYPE.

```bash
SC=../KunstDerFuge/tools/prototype/schema/musicxml.xsd
find Tests/MagnificatTests/Fixtures -name '*.musicxml' -exec xmllint --nonet --noout --schema "$SC" {} \;
```

A DOCTYPE is a *pointer* to a schema, not the schema. A validator supplies its own copy, so
whether the document names one changes nothing. Requiring a DOCTYPE would have rejected 8 of
the 19 machine-generated files for no benefit at all.

## Result 2 — validation misses what matters

| Corruption of the Mayer | Musically | Schema verdict |
| --- | --- | --- |
| Every `<octave>` shifted down by one | whole song in the wrong register | **passes** |
| Measure 5's dotted quarter cut to an eighth | bar is short by a beat | **passes** |
| `<duration>999</duration>` on a note typed `quarter` | flatly self-contradictory | **passes** |
| Every `<alter>-1</alter>` changed to `<alter>2</alter>` | every E flat becomes E double-sharp | **passes** |
| A note moved to `<staff>7</staff>` in a 2-staff part | staff does not exist | **passes** |
| `<octave>banana</octave>` | control | rejected |
| `</note>` closed as `</nte>` | control | rejected |

Five of seven pass. Those five are exactly the corruptions that yield a confident, plausible,
wrong transcript — a blind reader told the song sits an octave lower than it does has no way to
notice. The two that fail are both failures Magnificat's parser must detect anyway: it cannot
build a pitch from `banana`, and `XMLParser` halts on ill-formed input by itself.

KunstDerFuge measured the same thing from the other side, on generated output rather than
consumed input: *"Schema validity is useless here. Every run validates, including the 23.8% one.
Malformed output and wrong output are different failures, and only the first is what validation
catches."* (`../KunstDerFuge/docs/prototype-results.md`).

## Result 3 — it would nonetheless work on iOS

This settles a question KunstDerFuge left open (its §14.2, blocked on there being no iOS SDK on
the machine). Xcode 26.5 with an iOS 26.5 SDK is now installed, so it was tested directly.

- **`XMLDocument` does not exist on iOS.** Foundation's validating XML API is macOS-only;
  compiling `XMLDocument(data:)` for `arm64-apple-ios16.0` fails with `cannot find 'XMLDocument'
  in scope`. `XMLParser` compiles fine, but it does not validate.
- **libxml2 is in the iOS SDK** — `usr/include/libxml2/libxml/xmlschemas.h`, a `module.modulemap`
  and `libxml2.tbd` are all present.
- A Swift `xmlSchemaNewParserCtxt` / `xmlSchemaValidateDoc` sequence, reading with
  `XML_PARSE_NONET`, **compiles clean for `arm64-apple-ios16.0`**, and when built for macOS and
  run against the fixtures and the mutations it gives verdicts identical to `xmllint`.

So validation on iOS is available. It is simply not worth having, per Result 2, and it cannot
live in `Sources/Magnificat/` regardless — `CLAUDE.md` allows Foundation only, and libxml2 is C
interop plus a 387 KB bundled schema.

## Conclusion, written into SPEC.md §6.15

No schema validation in the core library. In its place, musical coherence checks the schema
cannot express — measure durations against the time signature, staff and voice references in
range, duration against notated type, backup before measure start — **reported as anomalies,
never fatal**, because real OMR output is routinely incoherent and a reader whose scanned page
produced a ragged bar still wants the transcript, with a warning rather than a refusal.
