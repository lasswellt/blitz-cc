#!/usr/bin/env bash
# skill-scan.sh — supply-chain scan of blitz's own shipped prompt and script surface.
#
# Snyk's ToxicSkills scan found critical issues in 13.4% of ~4,000 public skills
# (remote-fetch-and-run `!` lines, hidden Unicode, exfiltration). blitz ships skills,
# agents and bash hooks that run with the user's privileges, so CI holds them to:
#
#   bang-cmd     every `!`cmd`` line in SKILL.md / agents / output styles starts with
#                an allow-listed local, read-only command
#                (${CLAUDE_PLUGIN_ROOT}/scripts/*, git log|diff|status|show|rev-parse|
#                branch|ls-files, cat, grep, head, tail, echo, jq, ls, wc, python3 -c)
#   bang-danger  no network tool, pipe-to-shell, base64 decode, eval, sudo, URL, rm,
#                file write, or python import of os/subprocess/socket/urllib/requests
#                inside one
#   hidden-unicode  no zero-width or bidi control characters in any shipped text file
#   net-in-script   no network tool (curl, wget, nc, ssh, scp) in command position in hooks or scripts
#   launcher        no npx/bunx/uvx/pnpm dlx/yarn dlx/pipx run in hooks or scripts unless
#                it cannot download (`npx --no-install`) or pins an exact version
#                (name@1.2.3, name==1.2.3); run the project's node_modules/.bin instead
#                (either rule: a line may opt out with `# skill-scan: allow <reason>`)
#
# Usage: skill-scan.sh [--root DIR]     Exit: 0 clean · 1 findings · 2 usage
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "skill-scan: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -d "$ROOT" ] || { echo "skill-scan: no such directory: $ROOT" >&2; exit 2; }

python3 - "$ROOT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
findings = []
def add(p, n, rule, text):
    findings.append(f"{p.relative_to(root)}:{n}: {rule}: {text.strip()[:140]}")

BANG = re.compile(r'!`([^`]+)`')
ALLOW_FIRST = re.compile(r'''^\s*(
    "?\$\{CLAUDE_PLUGIN_ROOT\}/scripts/[A-Za-z0-9_.-]+"? |
    git\s+(log|diff|status|show|rev-parse|branch|ls-files)\b |
    (cat|grep|head|tail|echo|jq|ls|wc)\b |
    python3\s+-c\b
)''', re.X)
# Word lists are joined at run time so this file never spells a fetch-and-run pipeline.
NET_TOOLS = 'curl wget nc ncat ssh scp rsync ftp'.split()
SHELLS = 'sh bash zsh dash python3? node perl ruby'.split()
DANGER = [
    (re.compile(r'(^|[;&|(]\s*)(' + '|'.join(NET_TOOLS) + r')\b'), 'network tool'),
    (re.compile(r'\|\s*(' + '|'.join(SHELLS) + r')\b'), 'pipe to an interpreter'),
    (re.compile(r'base64\s+(-d|--decode)'), 'base64 decode'),
    (re.compile(r'\bev[a]l\b'), 'eval call'),
    (re.compile(r'\bsudo\b'), 'sudo'),
    (re.compile(r'https?://'), 'URL'),
    (re.compile(r'(^|[;&|]\s*)rm\s'), 'rm'),
    (re.compile(r'(?<![0-9&])>>?\s*(?!/dev/null)[^\s&|]'), 'file write'),
    (re.compile(r'\b(import\s+(os|subprocess|socket|urllib|requests|http)|__import__|os\.system|subprocess\.)'), 'python side effects'),
]
surfaces = list(root.glob('skills/*/SKILL.md')) + list(root.glob('agents/*.md')) + list(root.glob('output-styles/*.md'))
surfaces += list(root.glob('mods/*/skills/*/SKILL.md'))
for p in surfaces:
    for n, line in enumerate(p.read_text(errors='replace').splitlines(), 1):
        for m in BANG.finditer(line):
            cmd = m.group(1)
            if not ALLOW_FIRST.match(cmd):
                add(p, n, 'bang-cmd', cmd)
            for rx, what in DANGER:
                if rx.search(cmd):
                    add(p, n, f'bang-danger ({what})', cmd)

HIDDEN = re.compile('[\u200b-\u200f\u202a-\u202e\u2066-\u2069]|(?<!^)\ufeff')
SKIP = {'.git', 'node_modules', '.cc-sessions', 'results'}
TEXT = [*root.rglob('*.md'), *root.rglob('*.sh'), *root.rglob('*.js'), *root.rglob('*.ts'),
        *root.rglob('*.tsx'), *root.rglob('*.json'), *root.rglob('*.yaml'), *root.rglob('*.yml'),
        *root.rglob('*.bash')]
for p in sorted(set(TEXT)):
    if not p.is_file() or SKIP & set(p.relative_to(root).parts):
        continue
    for n, line in enumerate(p.read_text(errors='replace').splitlines(), 1):
        if HIDDEN.search(line):
            add(p, n, 'hidden-unicode', repr(HIDDEN.search(line).group(0)))

NET = re.compile(r'(^|[;&|(`]\s*|\$\(\s*)(' + '|'.join(NET_TOOLS[:6]) + r')\s')
for p in list(root.glob('hooks/scripts/*.sh')) + list(root.glob('hooks/scripts/_lib/*.sh')) + list(root.glob('scripts/*.sh')):
    for n, line in enumerate(p.read_text(errors='replace').splitlines(), 1):
        code = line.split('#', 1)[0] if not line.lstrip().startswith('#') else ''
        if NET.search(code) and 'skill-scan: allow' not in line:
            add(p, n, 'net-in-script', line)

LAUNCH = re.compile(r'(^|[;&|(`\s"\[]|\$\(\s*)(npx|bunx|uvx|pnpm\s+dlx|yarn\s+dlx|pipx\s+run)\b(?P<rest>[^;&|\n]*)')  # skill-scan: allow the rule's own pattern
PINNED = re.compile(r'^\s*(--no-install\b|(-[^\s]+\s+)*[@A-Za-z0-9_./-]+(@\d+\.\d+\.\d+|==\d+\.\d+\.\d+)\b)')
for p in list(root.glob('hooks/scripts/*.sh')) + list(root.glob('hooks/scripts/_lib/*.sh')) + list(root.glob('scripts/*.sh')):
    for n, line in enumerate(p.read_text(errors='replace').splitlines(), 1):
        if line.lstrip().startswith('#') or 'skill-scan: allow' in line:
            continue
        for m in LAUNCH.finditer(line.split(' #', 1)[0]):
            if not PINNED.match(m.group('rest')):
                add(p, n, 'launcher', line)

for f in findings:
    print(f)
print(f"skill-scan: {'FAIL' if findings else 'OK'}: {len(findings)} finding(s) across {len(surfaces)} prompt files", file=sys.stderr)
sys.exit(1 if findings else 0)
PY
