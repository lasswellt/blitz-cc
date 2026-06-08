# HTML Side-Output Helper

Shared-protocol convention + reusable `emit_html()` bash helper for the **additive HTML twin** pattern. Centralizes inline-CSS boilerplate and the `<stem>.html`-alongside-`<stem>.md` side-output rule so trivial/moderate adopters do not each reinvent it.

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

Reference this helper — do NOT inline a second copy of `emit_html`.

## `emit_html()`

Reads the just-written `.md`, wraps its body in an inline-CSS HTML shell, writes `<stem>.html`. Trust-tiered (`$2`): `untrusted` → HTML-escaped `<pre>` body (provably TB-4-safe, for content quoting fetched/untrusted sources); default `trusted` → styled `pandoc`(`-raw_html`)/`marked` converter + `sanitize_html` defense-in-depth (for local repo data). NO inline `<script>` is emitted on any path.

```bash
# Deterministic TB-4 scrub for converter output. Drops the active-content vectors that
# pandoc/marked propagate from untrusted markdown: <script> blocks, active embeds,
# on*= event handlers, and javascript: URIs. Idempotent; safe on escaped <pre> output.
sanitize_html() {
  # \x27 = single-quote in perl → whole script stays bash-single-quoted, no quote gymnastics.
  perl -0777 -e '
    my $h = do { local $/; <STDIN> };
    $h =~ s{<script\b[^>]*>.*?</script\s*>}{}gis;
    $h =~ s{<(iframe|object|embed|svg|math)\b[^>]*>.*?</\1\s*>}{}gis;
    $h =~ s{<(iframe|object|embed|svg|math)\b[^>]*/?>}{}gis;
    $h =~ s{\son\w+\s*=\s*("[^"]*"|\x27[^\x27]*\x27|[^\s>]+)}{}gis;
    # Neutralize href/src whose value resolves to a dangerous scheme after entity +
    # whitespace + control-char normalization — any quote style (covers leading-ws and
    # &#x6a;avascript: entity-encoded bypasses).
    $h =~ s{(href|src)\s*=\s*("[^"]*"|\x27[^\x27]*\x27|[^\s>]+)}{
      my ($attr, $raw) = ($1, $2);
      (my $val = $raw) =~ s/^["\x27]|["\x27]$//g;
      my $n = lc $val;
      $n =~ s/&#x([0-9a-f]+);?/chr hex $1/gie;
      $n =~ s/&#(\d+);?/chr $1/gie;
      $n =~ s/[\s\x00-\x1f]+//g;
      $n =~ m{^(?:javascript|data|vbscript):} ? qq{$attr="#"} : qq{$attr=$raw};
    }gie;
    print $h;
  '
}

emit_html() {
  # $1 = path to the just-written canonical .md (never modified)
  # $2 = trust: "untrusted" forces the escaped <pre> path (no raw-HTML converter); default
  #      "trusted" (local repo data) uses the styled pandoc/marked converter.
  local md="$1"
  local trust="${2:-trusted}"
  [ -f "$md" ] || { echo "emit_html: no such .md: $md" >&2; return 1; }
  local html="${md%.md}.html"
  local title; title="$(basename "${md%.md}")"

  # Body selection by trust (TB-4, security.md §3):
  #  - untrusted (research/audit quote FETCHED content) → escaped <pre> ONLY. Markdown
  #    converters pass raw HTML through, and a regex scrubber leaks across encodings
  #    (numeric → named entities → CSS …); HTML-escaping is the only COMPLETE close for
  #    untrusted input. Provably zero active content.
  #  - trusted (local repo data: dashboards/maps) → styled converter; pandoc with -raw_html
  #    drops raw inline HTML at the parser, marked is post-scrubbed by sanitize_html.
  local body
  if [ "$trust" = untrusted ]; then
    # Escaped already — structurally inert. Skip sanitize_html (it would mutate the
    # displayed literal text without adding safety).
    body="<pre>$(sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$md")</pre>"
  else
    if command -v pandoc >/dev/null 2>&1; then
      body="$(pandoc -f markdown-raw_html -t html --no-highlight "$md")"
    elif command -v marked >/dev/null 2>&1; then
      body="$(marked "$md")"
    else
      body="<pre>$(sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$md")</pre>"
    fi
    # Defense-in-depth scrub of the trusted converter output (marked passes raw HTML through).
    body="$(printf '%s' "$body" | sanitize_html)"
  fi

  # Self-contained shell: inline <style> in <head>, CSS vars, NO inline <script> (TB-4).
  cat > "$html" <<HTMLDOC
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
  :root { --primary: #2563eb; --accent: #f59e0b; --fg: #1f2937; --bg: #ffffff; --muted: #6b7280; }
  body { max-width: 60rem; margin: 2rem auto; padding: 0 1.25rem; font: 16px/1.6 system-ui, sans-serif; color: var(--fg); background: var(--bg); }
  h1, h2, h3 { color: var(--primary); line-height: 1.25; }
  h1 { border-bottom: 3px solid var(--accent); padding-bottom: .3rem; }
  a { color: var(--primary); }
  code, pre { font-family: ui-monospace, monospace; }
  pre { background: #f3f4f6; padding: 1rem; border-radius: 6px; overflow-x: auto; border-left: 3px solid var(--accent); }
  code { background: #f3f4f6; padding: .1rem .35rem; border-radius: 3px; }
  table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
  th, td { border: 1px solid #e5e7eb; padding: .5rem .75rem; text-align: left; }
  th { background: var(--primary); color: #fff; }
  tr:nth-child(even) { background: #f9fafb; }
  blockquote { border-left: 3px solid var(--muted); margin: 1rem 0; padding: .25rem 1rem; color: var(--muted); }
</style>
</head>
<body>
${body}
</body>
</html>
HTMLDOC

  echo "emit_html: wrote $html (twin of $md)" >&2
}
```

The `.md` argument is read-only; `emit_html` only ever writes `${md%.md}.html`.

## Adopters

- **quality-metrics** — `emit_html docs/metrics/dashboard.md` (Phase 3.3). Trusted local repo data → styled converter.
- **codebase-map** — `emit_html CODEBASE-MAP.md` (Phase 3 synthesis). Trusted local repo data → styled converter.
- **research** — `emit_html "$DOC_PATH" untrusted` (Phase 3.1, after `scope:` final + quality-gated). May quote fetched content → escaped `<pre>` (TB-4).
- **audit** — `emit_html "${REPORT_DIR}/audit-DATE.md" untrusted` (Phase 2.7), report only. NEVER twin `audit-DATE-epics.md` (machine `scope:`) or `-index.json`.
