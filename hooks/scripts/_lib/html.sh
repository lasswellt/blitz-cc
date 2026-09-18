#!/usr/bin/env bash
# _lib/html.sh — HTML side-output helpers (E-039 additive HTML twin, E-041 S6).
#
# Sourceable library; never executed directly:
#   . "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/_lib/html.sh"     # from a skill
#   . "$(dirname "$0")/../hooks/scripts/_lib/html.sh"        # from scripts/*.sh
#
# Provides: sanitize_html, emit_html
#   sanitize_html                 stdin → stdout; deterministic TB-4 scrub of converter output
#   emit_html <md> [trusted|untrusted]   writes <stem>.html next to <stem>.md (never touches the .md)
#
# Contract, gate (BLITZ_OUTPUT_FORMAT=html), trust tiers and the adopter list
# live in skills/_shared/html-template-helper.md — this file is the ONE place
# the bash bodies exist (the doc references it; never inline a second copy).
# Requires: perl (sanitize_html); pandoc or marked are optional (escaped <pre>
# fallback otherwise). Safe under set -euo pipefail.

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
