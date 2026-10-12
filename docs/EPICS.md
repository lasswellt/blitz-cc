# Epic numbering map

Two numbering schemes exist in this repository. Neither is renumbered; this table is the join.

| Roadmap scheme | Containment scheme (`docs/security/containment/SYNTHESIS.md`) | Alias | Status |
|---|---|---|---|
| E-001 … E-039 | — | — | Delivered across sprints 1–24 (see `CHANGELOG-ARCHIVE.md`); E-039 = opt-in HTML side-output |
| — | Epic 0 — Framework | E-SEC-0 | Landed (`skills/_shared/security.md`, TB-1…TB-5) |
| — | Epic 1 — Persistent-state validation | E-SEC-1 | Landed (`hooks/scripts/startup-validate.sh` on every `SessionStart`, quarantine path) |
| — | Epic 2 — Sub-agent trust boundary | E-SEC-2 | Landed (`source_trust` on every agent reply, capped and scanned interpolation) |
| — | Epic 3 — Fetched-content inspection | E-SEC-3 | Landed for research citations (`agents/research-critic.md` §2.1.5); other fetched content is not inspected (`SECURITY.md` ASI01 residual) |
| — | Epic 4 — Capability-grant audit | E-SEC-4 | Landed (`sec-capability-grant` registry row, `audit --pillar security`, skill-grant validator rule 12) |
| — | Epic 5 — Pre-trust hook hardening | E-SEC-5 | Landed (3.11.0: fail-closed guards, `blitz_guard_input`, capped echoes in `session-start.sh`) |
| — | Epic 6 — Permanent gate | E-SEC-6 | Landed (`check` security posture gate on every run, `audit --pillar security`) |
| E-040 … E-047 | — | — | Delivered in 2.5.0 (2026-09-18); the review that planned them is [docs/reviews/2026-09-18_cc-2.1.276-alignment/](reviews/2026-09-18_cc-2.1.276-alignment/README.md) |

Rules:

- New roadmap epics continue the `E-0NN` sequence from the highest number in this table.
- Containment epics keep their `Epic N` headings in SYNTHESIS.md and are referenced elsewhere as `E-SEC-N`.
- This file is the committed index; there is no roadmap skill.
