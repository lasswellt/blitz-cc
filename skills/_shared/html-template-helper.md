# HTML Side-Output Helper

Shared-protocol convention + reusable `emit_html()` bash helper (bodies in `hooks/scripts/_lib/html.sh`) for the **additive HTML twin** pattern. Centralizes inline-CSS boilerplate and the `<stem>.html`-alongside-`<stem>.md` side-output rule so trivial/moderate adopters do not each reinvent it.

Source: `docs/_research/2026-06-07_html-output-adoption.md` §6 (recommendation), §7 (implementation sketch), §9 (risks). Template gallery reference: https://github.com/anthropics/html-effectiveness (MIT).

## Contract

- **Additive only — never replace.** `emit_html` writes `<stem>.html` next to the canonical `<stem>.md`. It NEVER moves, renames, or replaces the `.md`. The `.md` stays the artifact the registry/roadmap/grep pipeline consumes — `roadmap extend` globs `**/*.md` for the `scope:` block; emitting `.html` *instead of* `.md` silently drops `scope:` at ingestion (§9 canonical-drift, the single highest-impact failure mode). Additive-twin is the only supported path.
- **Gate.** No-op unless `BLITZ_OUTPUT_FORMAT=html`. Default `md` → byte-identical existing behavior. Mirrors existing `BLITZ_DISPATCH` / `BLITZ_OUTPUT_INTENSITY` env conventions.
- **Self-contained output.** Inline `<style>` in `<head>`, CSS variables (`--primary`, `--accent`), no external deps, no build step, directly browser-openable.
- **Security (TB-4).** Trust-tiered (`security.md` §3). Adopters whose `.md` may quote FETCHED/UNTRUSTED content (research, audit) call `emit_html <md> untrusted` → the body is HTML-**escaped** into a `<pre>` block, never run through a raw-HTML-passing converter. This is the only COMPLETE close: markdown converters pass raw HTML through, and a regex scrubber leaks across encodings (numeric → named entities → CSS), so escaping is the sole provably-safe path for untrusted input. Trusted local-data adopters (dashboards/maps) use the styled converter — pandoc with `-raw_html` drops raw inline HTML at the parser; `marked` output is post-filtered by `sanitize_html` (defense-in-depth). The helper never emits an author-written `<script>` on any path.

## Gate usage

One-line guard at the adopter call site, immediately AFTER the canonical `.md` Write:

```bash
# Trusted local-data adopter (dashboards/maps):
[ "${BLITZ_OUTPUT_FORMAT:-md}" = html ] && emit_html <stem>.md
# Untrusted-content adopter (research/audit — may quote fetched text):
[ "${BLITZ_OUTPUT_FORMAT:-md}" = html ] && emit_html <stem>.md untrusted
```

Source `hooks/scripts/_lib/html.sh` — do NOT inline a second copy of `emit_html`.

## `emit_html()` and `sanitize_html()`

The bash bodies live in **one** place: [`hooks/scripts/_lib/html.sh`](../../hooks/scripts/_lib/html.sh) (sourceable library, E-041 S6). Skills and scripts source it — never paste a copy:

```bash
. "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/_lib/html.sh"     # from a skill
. "$(dirname "$0")/../hooks/scripts/_lib/html.sh"        # from scripts/*.sh
```

Signatures:

| Function | Signature | Behavior |
|---|---|---|
| `sanitize_html` | `stdin → stdout` | Deterministic TB-4 scrub for converter output: drops `<script>` blocks, active embeds (`iframe`/`object`/`embed`/`svg`/`math`), `on*=` handlers, and neutralizes `href`/`src` whose value resolves to `javascript:`/`data:`/`vbscript:` after entity + whitespace + control-char normalization. Idempotent; safe on escaped `<pre>` output. Requires `perl`. |
| `emit_html <md> [trust]` | `$1` = path to the just-written canonical `.md` (never modified); `$2` = `trusted` (default) or `untrusted` | Reads the `.md`, wraps its body in an inline-CSS HTML shell, writes `${md%.md}.html`. `untrusted` → HTML-escaped `<pre>` body only (provably TB-4-safe; for content quoting fetched sources). `trusted` → `pandoc -f markdown-raw_html` (drops raw inline HTML), else `marked`, else escaped `<pre>`; the converter output is post-scrubbed by `sanitize_html` (defense-in-depth). NO inline `<script>` is emitted on any path. Returns 1 when the `.md` is missing. Logs `emit_html: wrote <html> (twin of <md>)` to stderr. |

The `.md` argument is read-only; `emit_html` only ever writes `${md%.md}.html`.

## Adopters

- **quality-metrics** — `emit_html docs/metrics/dashboard.md` (Phase 3.3). Trusted local repo data → styled converter.
- **codebase-map** — `emit_html CODEBASE-MAP.md` (Phase 3 synthesis). Trusted local repo data → styled converter.
- **research** — `emit_html "$DOC_PATH" untrusted` (Phase 3.1, after `scope:` final + quality-gated). May quote fetched content → escaped `<pre>` (TB-4).
- **audit** — `emit_html "${REPORT_DIR}/audit-DATE.md" untrusted` (Phase 2.7), report only. NEVER twin `audit-DATE-epics.md` (machine `scope:`) or `-index.json`.
- **sessions** — `scripts/sessions-dashboard.sh --html` sources `_lib/html.sh` and runs `emit_html .cc-sessions/dashboard.md` (script consumer, E-041 S5). Feed/record text is sanitized (≤120 chars, `BLITZ_INJECTION_RX`) before it reaches the `.md`; the styled converter path is still post-scrubbed by `sanitize_html`.
