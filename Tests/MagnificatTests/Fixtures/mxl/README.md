# Compressed MusicXML fixtures

Three matched pairs, provided by the user on 28 August 2026 specifically to test compressed
`.mxl` support. Each `.mxl` and its same-named `.musicxml` sibling hold **identical content** —
confirmed byte-for-byte before these were used for anything:

```bash
diff <(unzip -p carmen.mxl carmen.xml) carmen.musicxml   # identical, and so for the other two
```

That makes each pair a real round-trip fixture: `Score(musicXML: mxlData)` must produce exactly
the same `Score` — and the same transcript — as `Score(musicXML: musicXMLData)` on the sibling.
No synthetic zip was constructed for testing; these are exactly what a real exporter produces.

| File | Entry | Compression | Notes |
| --- | --- | --- | --- |
| `Dichterliebe01.mxl` | `Dichterliebe01.xml` | DEFLATE | Schumann's song cycle. Largest of the three (226 KB uncompressed). |
| `carmen.mxl` | `carmen.xml` | DEFLATE | Bizet, an aria from *Carmen*. |
| `carmen-degraded.mxl` | `carmen-degraded.xml` | DEFLATE | The same piece, evidently passed through some further processing — well-formed XML throughout (`xmllint` confirms it), but not necessarily musically clean. Good adversarial input for the round-trip test: it must decompress correctly regardless of what is inside. |

All three `META-INF/container.xml` files follow the standard shape:

```xml
<container>
  <rootfiles>
    <rootfile full-path="carmen.xml" media-type="application/vnd.recordare.musicxml+xml"/>
  </rootfiles>
</container>
```

— confirming `.mxl` support needs to **read `container.xml` to find the root entry**, not just
grab the first or only plausible-looking file in the archive: the entry name does not match the
archive's own filename (`carmen.mxl` → `carmen.xml`, not `carmen.mxl.xml` or similar), and a
real archive could in principle hold more than one file.

## Provenance

Provided directly by the user for this feature. The underlying works (Schumann's *Dichterliebe*,
Bizet's *Carmen*) are long public domain; the provenance of this specific engraving/transcription
is not otherwise known to this repository. Treat as **test fixtures only** — do not assume
redistribution rights beyond that use without checking with the user first.
