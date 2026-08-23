# CLAUDE.md — Build Guide for Magnificat

This folder holds **Magnificat**, a **portable Swift library** that must work unchanged
in both an **iOS app** and a **desktop macOS application**.

Read `SPEC.md` first. It is the source of truth for *what* the library does.
This file is the source of truth for *how* to build it.

If `SPEC.md` is still a blank skeleton, **stop and ask the user to fill it in**.
Do not invent requirements.

---

## Non-negotiables

Every one of these must be true before you report the work as done:

1. **Portable core.** The library target imports `Foundation` and nothing else
   platform-specific. No `UIKit`, no `AppKit`, no `SwiftUI` in the library target — ever.
   If a capability genuinely needs the platform (file locations, keychain, networking
   policy), define a protocol in the core and let the *host app* inject an implementation.
2. **Test-driven development, with no exceptions.** Every change to behavior starts with
   a test that you have *run* and *watched fail* for the right reason, and ends with that
   same test run again and passing. See [Test-driven development](#test-driven-development).
3. **Thorough, complete automated test coverage.** See [Testing](#testing) below.
4. **A working command-line client** that demonstrates real usage. See [CLI](#cli-client).
5. **A `README.md`** that a newcomer can follow. See [README](#readme).
6. **Everything builds and all tests pass** with a single `swift build && swift test`.
   Never report success on an unverified build — run it, paste real output.
7. **`DIARY.md` is current.** Every increment of work is recorded there as it happens, and
   the file is written so that a session with no memory of this project can pick the work up
   from it alone. See [Diary](#diary).

---

## Project layout

Use Swift Package Manager. The library is named **Magnificat**. Create this structure:

```
Package.swift
SPEC.md                      # what to build (written by the user)
CLAUDE.md                    # this file
DIARY.md                     # the running record of the work (you keep this current)
README.md                    # how to use the library (you write this)
Sources/
  Magnificat/             # the portable library — Foundation only
  MagnificatCLI/          # the executable demo client
Tests/
  MagnificatTests/        # the test suite
```

`Package.swift` should declare, at minimum:

```swift
// swift-tools-version: 5.10
platforms: [.iOS(.v16), .macOS(.v13)]
```

Bump the tools version and platform minimums only if `SPEC.md` requires it, and say why
in the README. Add **no third-party dependencies** unless `SPEC.md` explicitly asks for
one; a dependency-free package is far easier to drop into two different apps.

## API design rules

- Public surface is deliberate and small. Mark everything `internal` by default and
  promote to `public` only what the spec's use cases need.
- Value types (`struct`, `enum`) by default; reference types only when identity or shared
  mutable state is genuinely required.
- Errors are a `public enum` conforming to `Error`, one case per distinct failure the
  caller can act on. No `fatalError` on caller-supplied input, no silent `try?`.
- No global mutable state and no singletons — they break testability and break apps that
  need two instances.
- Inject anything non-deterministic (clock, UUIDs, randomness, file system, network)
  behind a protocol with a sensible default. Tests must never depend on wall-clock time,
  the real network, or the real disk.
- If the type is used across concurrency domains, make it `Sendable` and say so.
- Document every public symbol with `///` doc comments, including what it throws.

## Test-driven development

**This library is built test-first. Writing implementation code before a failing test
exists for it is a process violation, not a shortcut.** This applies to new features, bug
fixes, refactors that change behavior, and edge cases discovered mid-work.

### The loop

For each increment of behavior — one rule, one error case, one edge case; not a whole
feature at once:

1. **Write the test.** Express the behavior from `SPEC.md` as the smallest test that
   captures it. Assert on the real expected value, never on "does not crash".
2. **Run it and watch it fail.** Run `swift test` and confirm the new test *fails*.
3. **Verify the failure is the right one.** A red test is not automatically a valid red
   test. Read the message and confirm it fails because the behavior is missing — an
   assertion mismatch, or an unimplemented path. If it fails because of a typo, a compile
   error in the test itself, a missing fixture, or a crash somewhere unrelated, **fix the
   test and go back to step 2**. A test that fails for the wrong reason proves nothing,
   and a test that passes immediately is testing something that already worked — sharpen
   it until it fails, or delete it.
4. **Write the minimum implementation** that makes that test pass. No speculative
   generality, no untested branches added "while you're in there".
5. **Run the tests again.** The new test passes and **every previously passing test still
   passes**. Run the whole suite, not just the new test — a green new test alongside a
   regression elsewhere is a failed step.
6. **Refactor if warranted**, then run the full suite again to confirm it is still green.
7. Repeat.

### Rules

- Never write implementation and its test in the same step and then run the suite once at
  the end. The failing run in step 2 is the point of the exercise; skipping it means you
  never proved the test can detect the bug it claims to guard against.
- Never edit a test to match implementation output you did not predict. If a test fails
  after a change, the default assumption is that the code is wrong. Change the test only
  when you can state plainly why the *test's* expectation was wrong, and say so in your
  report to the user.
- Never delete, skip, comment out, or weaken a failing test to get to green.
- Fixing a bug starts with a test that reproduces it and fails. Reproduce first, fix second.
- If you cannot make a test fail before implementing — the behavior is already correct, or
  the case is unreachable — say so explicitly instead of quietly writing the code anyway.
- The CLI is held to the same standard: its argument parsing and exit codes get tests
  written first, like anything else.

### Reporting

Keep a running record of the loop and show it to the user as you go. For each increment,
report the test name, the **failing** run's output (the assertion message, trimmed to the
relevant lines), and the **passing** run's output afterwards. Paste real terminal output —
never summarize a run you did not execute, and never claim red-then-green from memory.

## Testing

Coverage must be **thorough and complete**, not token. Concretely:

- Every public function, initializer, and computed property is exercised.
- Every error case in the public error enum has a test that provokes it.
- Boundary and degenerate inputs: empty, single element, maximum size, zero, negative,
  Unicode text, malformed input.
- Round-trip tests wherever encoding/decoding or serialization is involved.
- Concurrency: if the API is used from multiple tasks, test it under concurrent access.
- Tests are deterministic and hermetic — no network, no sleeps, no shared temp paths, no
  ordering dependencies between tests. Use `FileManager.default.temporaryDirectory`
  with a unique subdirectory and clean up in teardown when disk access is unavoidable.
- Name tests for the behavior they pin down, not the method they call:
  `throws_whenBudgetIsNegative`, not `testInit3`.

Use **Swift Testing** (`import Testing`, `@Test`, `#expect`) if the installed toolchain is
Swift 6 or newer; otherwise use **XCTest**. Check with `swift --version` and pick one —
do not mix both in the same suite.

Measure coverage and report the number:

```bash
swift test --enable-code-coverage
```

Aim for ≥90% line coverage of the library target. If a line is genuinely unreachable,
either delete it or explain in the README why it stays.

## CLI client

`Sources/MagnificatCLI` is a demo, not a product. Its job is to prove the library is
usable from outside and to give the user something to run in 10 seconds.

- Keep it thin: parse arguments, call the library, print results, exit with a meaningful
  status code (`0` success, non-zero failure). All real logic lives in the library.
- Parse arguments with `CommandLine.arguments` by hand unless `SPEC.md` approves adding
  `swift-argument-parser`.
- Support `--help` and cover the main use cases from `SPEC.md`, one subcommand or flag each.
- Print errors to `stderr`, results to `stdout`, so it composes with other tools.
- It must run: `swift run MagnificatCLI --help`.

## README

Write `README.md` for someone who has never seen this package. Include:

1. One-paragraph description of what the library does and who it is for.
2. Requirements — Swift version, iOS/macOS minimums.
3. Installation — SwiftPM `.package(url:from:)` snippet, plus a note on adding a local
   package in Xcode for both an iOS target and a macOS target.
4. Quick start — a copy-pasteable example that compiles.
5. Usage guide covering each main use case from `SPEC.md`, with code.
6. Error handling — the error cases and what a caller should do about each.
7. CLI usage — every flag, with example invocations and their output.
8. Testing — how to run tests and the current coverage number.
9. Any known limitations or deliberate non-goals.

Show real code that actually works. Run every snippet before committing it.

## Working method

- Order of work: library, then CLI, then README — but within each, tests come first, one
  red-green cycle at a time (see [Test-driven development](#test-driven-development)).
- Work in small increments. Every increment ends on a full, green `swift build && swift test`.
- Prefer clarity over cleverness; this code will be read by people integrating it into
  two different apps.
- When `SPEC.md` is ambiguous, ask the user rather than guessing. If a question is minor
  and the work can proceed either way, pick the obvious default, note the assumption in
  the README, and keep going.
- Report honestly: if something is incomplete or a test fails, say so plainly with the
  output.

## Diary

`DIARY.md` is the running record of how this library got built. Its purpose is **handover**: a
fresh session, a new contributor, or you after a context renewal must be able to read it and
resume without asking anyone anything. Assume the reader has none of your context and cannot
ask you a question — they have this file, `SPEC.md`, `CLAUDE.md`, and the code.

### Structure

Two parts, and the split is what makes the file usable once it is long:

1. **`## Where things stand`** at the top — a snapshot, **rewritten in place** every session.
   What is built, what is green, what the next step is, and what is known-broken. A reader must
   get the current state from this section alone, without reading the log below it.
2. **`## Log`** underneath — append-only, **newest last**, one entry per increment of work.
   Never rewrite or tidy a past entry. If an earlier entry turns out to be wrong, say so in a
   *new* entry; the mistake and its correction are both part of the record.

### When to write an entry

Write one for each meaningful increment — normally each completed red-green-refactor cycle, and
also for anything that changes the shape of the work: a decision, a surprise, a dead end, a
`SPEC.md` clarification, a fixture added, a rule that turned out to be wrong. **Not** one per
tool call, and not a blow-by-blow of everything you typed.

Write it **as the work happens**, not reconstructed at the end of a session. A diary assembled
from memory after the fact is exactly the document that quietly invents a red-green cycle that
never ran.

### What an entry contains

```markdown
### <date> — <short title>

**Goal.** The one behaviour this increment was meant to add.

**Test.** The test name, and what it asserts.

**Red.** The real failure output, trimmed to the assertion. Say why it is the *right* failure.

**Green.** The passing output, and the full-suite result alongside it.

**Decision / surprise.** Anything a future reader would otherwise have to rediscover: why an
approach was rejected, what the MusicXML actually turned out to contain, a rule in `SPEC.md`
that needed sharpening.

**State.** What is green now, and the next step.
```

Trim the sections that do not apply — a non-coding entry has no red or green — but never drop
**Decision / surprise** when there was one. That section is the reason the file is worth
keeping; the rest can be reconstructed from git and the test suite, and that cannot.

### Rules

- Paste **real** terminal output, exactly as `CLAUDE.md`'s [Reporting](#reporting) rule
  requires. Never summarise a run you did not execute or reproduce one from memory.
- Record dead ends and wrong turns. A diary of unbroken success is not a record, and the next
  session will repeat whatever you quietly abandoned.
- Update `## Where things stand` **in the same commit** that invalidates it. A stale snapshot is
  worse than none, because it reads as current.
- Keep entries short. Someone should be able to read the whole log in ten minutes and know how
  the library got to where it is.
- If you end a session mid-increment, say so explicitly in `## Where things stand` — which test
  is red, what you were part-way through, and what you had ruled out.

## Definition of done

```bash
swift build
swift test --enable-code-coverage
swift run MagnificatCLI --help
```

All three succeed, coverage is ≥90%, `README.md` is complete and its examples run, and no
platform UI framework appears anywhere under `Sources/Magnificat/`.

`DIARY.md` is current: its `## Where things stand` describes the finished state, and its log
records how the work actually went, dead ends included.

And every piece of behavior in the library got there through a test that was written
first, run, seen to fail for the right reason, and then run again and seen to pass.
