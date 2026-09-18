# Epic numbering map

Two numbering schemes exist in this repository. Neither is renumbered; this table is the join.

| Roadmap scheme | Containment scheme (`docs/security/containment/SYNTHESIS.md`) | Alias | Status |
|---|---|---|---|
| E-001 … E-039 | — | — | Delivered across sprints 1–24 (see `CHANGELOG-ARCHIVE.md`); E-039 = opt-in HTML side-output |
| — | Epic 0 — Framework | E-SEC-0 | Landed (`skills/_shared/security.md`, TB-1…TB-4) |
| — | Epic 1 — Persistent-state validation | E-SEC-1 | Partially landed (`hooks/scripts/startup-validate.sh`, quarantine path) |
| — | Epic 2 — Sub-agent trust boundary | E-SEC-2 | Open |
| — | Epic 3 — Fetched-content inspection | E-SEC-3 | Open |
| — | Epic 4 — Capability-grant audit | E-SEC-4 | Open |
| — | Epic 5 — Pre-trust hook hardening | E-SEC-5 | Open |
| — | Epic 6 — Permanent gate | E-SEC-6 | Open |
| E-040 … E-047 | — | — | Planned; see [docs/reviews/2026-09-18_cc-2.1.276-alignment/](reviews/2026-09-18_cc-2.1.276-alignment/README.md) |

Rules:

- New roadmap epics continue the `E-0NN` sequence from the highest number in this table.
- Containment epics keep their `Epic N` headings in SYNTHESIS.md and are referenced elsewhere as `E-SEC-N`.
- `/blitz:roadmap` writes runtime epic registries to `docs/roadmap/` (gitignored on this repo); this file is the committed index.
