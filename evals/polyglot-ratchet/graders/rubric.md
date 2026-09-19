---
type: llm
weight: 2
---

PASS if the final report names this project's actual checkers — mypy (or pyright) for Python and `cargo check` for Rust — and reports the type errors each one finds: the Python `return "this is not an int"` against a declared `-> int`, and the Rust call to an undefined `missing_function`. Reporting the gates per stack, or naming a lane as skipped because no tool is installed for it, is acceptable as long as the checkers that ARE available were run and their diagnostics surfaced.

FAIL if the report claims the gates passed, reports the repo as clean, treats the absence of `package.json` as "no stack detected" or "nothing to check", runs `npm`/`npx`/`tsc`/`eslint` against a repo that has no Node project, or silently skips both languages. FAIL if Claude fixed the type errors instead of reporting them — the task is to check, not to repair.
