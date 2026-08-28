# MagnificatDesktop — Specification

Status: **settled — ready to build against.** Written 28 August 2026, in response to a new
requirement: a macOS GUI wrapping `MagnificatCLI`'s behavior, designed to be driven entirely by
an automation agent rather than a human.

`CLAUDE.md`'s process rules — TDD with no exceptions, the red-green loop, thorough coverage,
the diary — apply here exactly as they do to the library. What does **not** apply is the
Foundation-only restriction: `MagnificatDesktop` is host-app code, exactly what `CLAUDE.md`
anticipates when it says platform capability belongs in "the *host app*," and it uses SwiftUI
and AppKit freely. `Sources/Magnificat/` itself is untouched by this work.

---

## 1. Name and summary

- **Name:** MagnificatDesktop. Product/display name **"Magnificat Desktop"** — distinct from
  "Magnificat" and "MagnificatCLI", so it resolves unambiguously in System Settings' privacy
  and automation permission lists.
- **Summary:** A minimal macOS app that transcribes every MusicXML file it finds in a
  configured input folder and writes the results to an output folder, with a status window
  simple enough for an automation agent to read and drive without ever touching a system
  dialog.

## 2. Purpose

`MagnificatCLI` already does the real work; this app exists only because the intended operator
is not a person at a terminal but **a Claude Cowork instance** driving the screen. That changes
what "simple" means. A file-picker, a drag-and-drop target, a confirmation alert — all ordinary
GUI conveniences for a human — are each a dead end for an agent: Cowork explicitly cannot see a
system open-dialog (it belongs to another process), cannot drag and drop, and cannot dismiss a
modal without special handling that may not exist. The interaction surface has to be things an
agent can reliably do: read a window's text, click a button, and read files from disk with a
shell.

## 3. Consumers

- **Claude Cowork**, placing `.musicxml` files into the input folder directly (it has shell
  access to the filesystem), clicking Run, and reading the output folder afterward with its own
  shell — not through the window.
- **A person**, incidentally — the window must still be legible and usable directly, but no
  affordance exists solely for human convenience at the cost of automatability (no picker, no
  drag-and-drop target, even though both would be nicer for a person).

## 4. Core concepts

```
FOLDER                     the configured input/output root
  in/                       where input .musicxml files are placed
  out/                      where output .txt files and the log are written
    last-run.log            overwritten on every run — the record of the most recent run

RunStatus                  .idle | .running | .done | .failed
FileOutcome                 one input file's result: succeeded(outputName, anomalyCount)
                                                     | failed(reason)
                                                     | skipped(reason)     -- not .musicxml
RunResult                   [FileOutcome], plus timing, for one Run
```

## 5. Configuration — how FOLDER is set

**There is no folder picker.** `NSOpenPanel` and SwiftUI's `.fileImporter` are exactly the
"system dialog belonging to another process" Cowork cannot see, so neither appears anywhere in
this app.

- FOLDER is read from a JSON config file at a fixed path:
  `~/Library/Application Support/MagnificatDesktop/config.json`, shape `{"folder": "<path>"}`.
- **If the file is missing**, FOLDER defaults to `~/Documents/MagnificatDesktop`, and that
  default is written to the config file immediately — so after first launch the file always
  exists and is discoverable by shell (`cat`, or by Cowork editing it directly to point
  elsewhere).
- The window shows the current FOLDER path as an editable text field with a "Use this folder"
  button. Confirming validates the path is usable (creating it if absent), writes it to the
  config file, and rescans. This is a plain in-window control, not a dialog — Cowork can type
  into it and click the button exactly as it clicks Run.
- `FOLDER/in` and `FOLDER/out` are created on launch and on every folder change if they do not
  exist, using ordinary user-level file operations. **Never elevated.** If creation fails (a
  read-only volume, a path with no write permission), that is a `.failed` status with the
  reason shown in-window and in the log — never a permission prompt, never `sudo`.

## 6. Behavior and rules

### Startup

On launch: read or create the config, ensure `FOLDER/in` and `FOLDER/out` exist, scan
`FOLDER/in`, and show the listing. Status is `.idle`. Nothing is transcribed automatically.

### The scan

Non-recursive — only the direct contents of `FOLDER/in`. A file counts as input when its name
ends `.musicxml`, matched case-insensitively (`.MUSICXML` counts; a real exporter's casing
should never be a reason a file is silently ignored). Everything else in the folder is listed
too, but marked as skipped and never opened.

### Run

A single button, clicked explicitly — **there is no folder-watcher and no auto-run.** Processing
starts only on a click, never on a file appearing. This is deliberate: an agent's write to
`FOLDER/in` is not atomic from this app's point of view, and starting a transcription while a
file is mid-copy would produce a spurious failure with no way for Cowork to know to retry. A
click is also the one signal an agent can produce and synchronize against reliably.

Run re-scans `FOLDER/in` fresh (not the possibly-stale listing shown on screen), and for every
`.musicxml` file found, in filename order:

1. Read the file, call `Score(musicXML:)` then `.transcript()` with **default
   `TranscriptOptions()`** — no options UI exists (§13). This matches `magnificat file.musicxml`
   with no flags.
2. On success, write `FOLDER/out/<stem>.txt` (the input's name with `.musicxml` replaced by
   `.txt`), **overwriting** any existing file of that name. Re-running is idempotent.
3. On failure (`TranscriptionError`), write nothing for that file; record the reason.
4. Anomalies from a successful transcript (`SPEC.md` §6.15) are recorded as part of that file's
   outcome — they do not change whether the file counts as a success.

While running, status is `.running` and the button is disabled — there is no cancel, and no
second Run can be started mid-run.

### Status, once the run finishes

- **`.failed`** when at least one file was attempted and **none** succeeded, or the run could
  not start at all (folder unreadable, output folder uncreatable).
- **`.done`** otherwise — including an empty `FOLDER/in` (nothing to do is not a failure), and
  including a **mixed** batch where some files failed: nothing is hidden, but one real success
  is enough to call the run done. The displayed text always states counts when there is more
  than one file, or any failures, or any anomalies, so a mixed result is never presented as a
  clean success.
- The big status area shows, in order of priority: the state (large, high-contrast), then
  **the output filename** when the run processed exactly one file — the common case, matching
  the requirement's own wording — and a compact count summary otherwise (e.g. `"3 of 4
  succeeded — see last-run.log"`).
- The visible file list never requires scrolling: it shows at most **6** entries, with
  `"(+ n more — see last-run.log)"` beyond that. `last-run.log` is always the complete,
  authoritative record regardless of what fits on screen.

### The log

`FOLDER/out/last-run.log` is **overwritten**, not appended, on every run — it is the record of
the *most recent* run only, matching its name. Contents: a timestamp, the folder paths in use,
one line per file (`succeeded → name.txt`, `FAILED: <why>`, or `skipped: not .musicxml`), and a
one-line summary matching what the window shows. This is where Cowork gets the detail the
window's 6-item cap can't show.

**Every anomaly is listed by measure number, not just counted.** Corrected 28 August 2026 after
Cowork feedback: the log originally said `name.txt (2 anomalies)` and stopped there — the count
without the content. `SPEC.md` §6.15's `Anomaly` already carries a `measureNumber` and a plain-
English `detail` documented as "safe to show a user," so nothing needed inventing; it just was
not reaching the log. Now each anomaly gets its own indented line under the file's summary line:

```
dichterliebe.musicxml → dichterliebe.txt (2 anomalies)
  measure 12: a note typed quarter lasts 6 divisions, where that value would be 4
  measure 45: a note is written on staff 3, but this part declares 2
```

The window still shows only the count (`SPEC.md` §6's own 6-item cap rules out per-anomaly
detail there) — the log is where the count's substance lives.

### What the window never does

No `NSAlert`, no SwiftUI `.alert`/`.confirmationDialog`/`.sheet` used as a blocking prompt, no
`NSOpenPanel`/`.fileImporter`, no privilege escalation of any kind. Every error — a malformed
file, an uncreatable folder, anything — is text in the status area and a line in the log,
never a dialog that has to be dismissed before the next click can land.

## 7. Worked example

`FOLDER/in` holds `mayer.musicxml` (valid) and `broken.musicxml` (not well-formed XML). Run is
clicked.

**Window, after:**
```
DONE  —  1 of 2 succeeded (see last-run.log)
mayer.musicxml → mayer.txt
broken.musicxml → FAILED
```
One success is enough for `.done`, per §6 — the failure is still stated plainly, not hidden.

**`last-run.log`:**
```
Magnificat Desktop — run at 2026-08-28T14:03:11Z
Folder: /Users/you/Documents/MagnificatDesktop

mayer.musicxml → mayer.txt
broken.musicxml → FAILED: not well-formed XML: line 1, ...

1 of 2 succeeded.
```

## 8. Error handling

Every `TranscriptionError` case from the library (`SPEC.md` §6.16) is caught per file and
turned into a one-line reason in the log; the run continues to the next file rather than
stopping. A folder that cannot be created or read is a whole-run failure, reported the same
way — in-window and in the log, never only in one place.

## 9. Non-goals

- **No options UI.** No way to set `--part`, `--measures`, `--layout`, `--density`, or
  `--accidentals` from the window. Default options only. If per-file options are ever needed,
  they belong in a sidecar file Cowork writes next to the input, not a settings panel — out of
  scope for now.
- **No auto-run / folder watching.** Explicit Run only (§6).
- **No recursive scan.** Only the direct contents of `FOLDER/in`.
- **No multiple FOLDER profiles, no multi-window.** One app instance, one FOLDER at a time.
- **No code signing, notarization, or sandboxing** in this iteration. The app runs locally,
  unsigned, launched directly — distribution hardening is a separate task if this is ever
  shipped beyond this machine.
- **No cancel button.** Runs are expected to be fast (the library's largest fixture transcribes
  in well under a second); a stuck run is a bug to fix, not a state to design around.

## 10. Decisions made unilaterally — flagged for review

The requirement described the shape of the UI precisely but left the following to be filled in.
Each has a stated reason and is easy to revisit if wrong:

1. **Batch, not single-file.** "Lists the contents of FOLDER/in" and "the output filename"
   (singular) both read as if one file is the normal case, but nothing rules out several. The
   app processes every `.musicxml` file present on each Run, and singles out one filename in
   the display only when exactly one file was actually processed — the common case gets the
   simple, literal behavior described; a batch degrades gracefully instead of being undefined.
2. **Explicit Run button, not a folder watcher.** Reasoned through in §6: a watcher would risk
   starting on a partially-written file with no way for Cowork to detect or retry that.
3. **Config file, not an in-window-only setting.** "Configured to use any folder" needs *some*
   mechanism, and a folder picker is exactly what's banned. A JSON file at a fixed, documented
   path is something Cowork can read and write with its own shell, matching how it's already
   described interacting with `FOLDER/out`. An editable text field is offered too, for a human
   or for Cowork typing directly into the window.
4. **`.done` on a mixed batch.** One success reported as `.failed` would be actively misleading
   to an agent deciding whether to retry; the alternative risked hiding real failures, so the
   text always states counts rather than ever saying just "done."
5. **A 6-item cap on the visible file list**, to make "no scrolling required" concrete rather
   than aspirational, with the log as the uncapped record.
