# Magnificat — Library Specification

> Fill in every section below. This file is the source of truth for **what** the library
> does; `CLAUDE.md` covers **how** it gets built. Delete the italic prompts as you go, and
> write "N/A" for anything that genuinely does not apply — an empty section reads as
> "not yet decided" and the agent will stop and ask.

---

## 1. Name and one-line summary

*The library's name (used for the SwiftPM target) and a single sentence describing it.*

- **Name:** Magnificat *(SwiftPM targets: `Magnificat`, `MagnificatCLI`, `MagnificatTests`)*
- **Summary:**

## 2. Purpose and motivation

*What problem does this solve? Why does it need to be a shared library rather than code
living in each app? Two or three paragraphs is plenty.*

## 3. Consumers

*Who calls this library, and in what context?*

- iOS app: *what it uses the library for*
- macOS app: *what it uses the library for*
- Command-line demo client: *what the demo should show off*
- Anything else (extensions, widgets, server, tests):

## 4. Core concepts and domain model

*The nouns of the library — the main types and what each represents. Include the important
fields and how the types relate. Diagrams or bullet trees are fine.*

## 5. Public API

*The verbs — what a caller can actually do. One entry per operation:*

### `operationName`

- **Purpose:**
- **Inputs:** *names, types, valid ranges*
- **Output:** *type and meaning*
- **Errors:** *what can go wrong, and what the caller should do*
- **Notes:** *async? throwing? thread-safety expectations?*

*(Repeat for each operation. Sketch signatures if you have them in mind; the agent will
refine them, but it will not invent operations you did not list.)*

## 6. Behavior and rules

*The logic that is easy to get wrong: validation rules, ordering, precedence, rounding,
defaults, limits, state transitions. Be specific — this section is what the tests get
written against.*

## 7. Worked examples

*Two or three concrete input → output examples. These become test cases verbatim, so make
them exact.*

| Input | Expected result |
| ----- | --------------- |
|       |                 |

## 8. Data, persistence, and formats

*Does the library read or write anything? File formats, JSON/Codable shapes, schemas,
migration rules, and where data should live. If the library is pure computation with no
I/O, say so.*

## 9. Platform boundaries

*Anything the library needs from the host app rather than doing itself — file locations,
keychain, networking, user permissions, notifications, background execution. Each of these
becomes an injected protocol, so list them explicitly.*

## 10. Non-functional requirements

- **Performance:** *expected input sizes, latency budgets*
- **Concurrency:** *called from multiple threads/tasks? must types be `Sendable`?*
- **Memory:** *any hard limits*
- **Localization / Unicode:** *text handling expectations*
- **Accessibility / privacy:** *sensitive data, logging restrictions*

## 11. Platform and toolchain targets

- Minimum iOS version:
- Minimum macOS version:
- Swift version:
- Third-party dependencies allowed? *(default: none — justify any exception)*

## 12. CLI client scope

*What the demo command-line client should let a user do. Sketch the commands and flags you
want, and one example session.*

## 13. Explicit non-goals

*What this library deliberately does NOT do. Just as important as the goals — it stops
scope creep.*

## 14. Open questions

*Anything you have not decided. The agent will ask about these before building rather than
guessing.*
