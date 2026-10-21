# SECTION 6 — MODULE TECHNICAL APPENDIX

Alphabetical glossary of every technical concept used in M2, for merging into the Master
System Design Document.

| Technical Term / Syntax Used | Plain-English Definition | 1-Sentence Everyday Analogy |
|---|---|---|
| `async` / `await` / `Future` | Marks work that finishes later and pauses a function until it does, without freezing the app. | Ordering a coffee and waiting at the counter rather than blocking the whole queue. |
| Boundary validation | Checking everything a caller hands in, at the door, before any real work starts. | The bouncer checking IDs before anyone gets into the club. |
| Backoff (retry backoff) | Waiting a little longer before each retry so a struggling step isn't hammered. | Knocking again after a pause instead of pounding the door non-stop. |
| Control switch (C3, C2, C7) | A decision or business rule — a yes/no that changes what happens. | The light switch on the wall: it decides, it does not carry the electricity. |
| Data pipe (D3, D1) | The plumbing that stores or moves data, doing no deciding of its own. | The water pipes in a house — they carry water but never choose the temperature. |
| Delegation | Passing a job to the component that owns it instead of duplicating the rule. | Asking the librarian to file the book rather than filing it yourself in a second system. |
| Dependency injection | Handing a component the helpers it needs, rather than letting it build them itself. | Being given the tools you need instead of rummaging in a locked cupboard. |
| `epubx` | A pure-Dart EPUB parser (no platform code). | A translator who works entirely from the text, needing no special equipment. |
| Error shape (E1–E9) | The one agreed object every failure is reported in. | A standard incident form, the same fields no matter the incident. |
| Extension check | Confirming a file ends in .pdf or .epub before opening it. | Checking the label on a tin before opening it. |
| Fake (test double) | A stand-in that behaves predictably so a test can run without the real device. | A crash-test dummy standing in for a real passenger. |
| `file_picker` | A Flutter plugin that opens the device's file chooser. | A shop assistant who fetches the file you point at. |
| FNV-1a hash | A small, fast, stable way to turn a string into a fixed number. | A stamp that always prints the same code for the same word. |
| Idempotency key | A unique tag on a write so a repeated click or retry can be recognised and ignored. | A numbered claim ticket: hand it in twice, you still get one coat. |
| `int.fromEnvironment` / `String.fromEnvironment` | Reads a value supplied at build time, falling back to a safe default. | A thermostat that uses your set point but defaults to room temperature if unset. |
| Interface (abstract class) | A named set of methods a component promises to provide. | A plug standard — any plug that matches fits. |
| LibraryStorePort | M2's own declaration of the slice of M1 it needs, so M2 depends on the contract not the file. | A menu of what you may order, rather than the whole kitchen. |
| M1 (Library Store) | The only component that touches the database. | The single librarian who owns the catalogue. |
| M2 (Book Intake) | Takes a book in and hands the clean result to M1. | The front-desk clerk who checks your book and passes it to the librarian. |
| Nominally typed (Dart) | A class only satisfies an interface if it explicitly says it implements it. | A club that only lets you in if your name is on the list, even if you look the part. |
| PageExtractor port | The injectable boundary behind which pdfx/epubx live. | A specialist you phone for a page count, rather than doing it yourself. |
| `part` directive | Marks a file whose code is stitched into another; in Dart it must appear after all imports. | A page inserted into a book after the table of contents, not before it. |
| `pdfx` | A Flutter plugin that reads PDFs using platform code. | A translator who needs a special machine that only exists in the office. |
| Pin (version pin) | Writing one exact version instead of "any recent one". | A recipe that says 250 g, not "some". |
| Port (injected interface) | A named doorway through which a platform capability is reached. | A service hatch in a wall — you pass things through it, you don't knock the wall down. |
| Retry | Trying a failed action again, up to a limit. | Trying the door again after it jams once. |
| `schema_version` | The number naming which version of the data contract a message speaks. | A form's edition number so both sides know they are on the same revision. |
| Socket contract | The agreed shape of what goes in and what comes back. | A plug and socket that only fit together one correct way. |
| Spine item count (EPUB) | The number of content documents in an EPUB, used as its "page count" because EPUB has no fixed pages. | Counting the chapters in a book because the pages reflow to fit any screen. |
| Timeout | Giving up on a slow step after a fixed time. | Leaving the queue if it hasn't moved in fifteen minutes. |
| Transaction | A group of writes that all succeed together or all fail together. | A bank transfer that either moves the money both ways or not at all. |
| UUID | A long random-looking identifier that will not clash with another. | A serial number so long and random it never repeats. |

## Version stamp

M2 Book Intake — **v1.0** (first build).
