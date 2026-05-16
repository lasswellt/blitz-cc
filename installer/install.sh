#!/usr/bin/env bash
set -euo pipefail

# Blitz Claude Code Plugin — Installer Bootstrap
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lasswellt/blitz/main/installer/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/lasswellt/blitz/main/installer/install.sh | bash -s -- --yes
#
# If Node.js/npx is available, delegates to the full npx installer.
# Otherwise, performs a minimal bash+python3 install.

REPO_URL="https://github.com/lasswellt/blitz.git"
MARKETPLACE_NAME="blitz"
PLUGIN_NAME="blitz"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
BYEL='\033[1;93m'
BCYN='\033[0;96m'
BWHT='\033[1;97m'

info()    { echo -e "    ${GREEN}✓${NC} $*"; }
warn()    { echo -e "    ${YELLOW}⚠${NC} $*"; }
fail()    { echo -e "    ${RED}✖${NC} $*"; }
header()  { echo -e "\n  ${BOLD}$*${NC}"; }

echo ""
echo -e "${BYEL}   ─── ⚡ ──────────────────────────────────${NC}"
echo ""
echo -e "${BYEL}   ██████╗ ██╗     ██╗████████╗███████╗${NC}"
echo -e "${YELLOW}   ██╔══██╗██║     ██║╚══██╔══╝╚══███╔╝${NC}"
echo -e "${BWHT}   ██████╔╝██║     ██║   ██║     ███╔╝ ${NC}"
echo -e "${BCYN}   ██╔══██╗██║     ██║   ██║    ███╔╝  ${NC}"
echo -e "${CYAN}   ██████╔╝███████╗██║   ██║   ███████╗${NC}"
echo -e "${DIM}   ╚═════╝ ╚══════╝╚═╝   ╚═╝   ╚══════╝${NC}"
echo ""
echo -e "${CYAN}   ──────────────────────────────── ⚡ ───${NC}"
echo ""
echo -e "${DIM}     Claude Code Plugin Installer · v1.12.1${NC}"
echo -e "${DIM}       38 skills · 10 agents · 27 hooks${NC}"
echo ""

# ── Try npx first ──────────────────────────────────────────────
if command -v npx &>/dev/null; then
  header "Node.js detected — using full installer"
  exec npx blitz-cc@latest "$@"
fi

# ── Minimal bash+python3 fallback ──────────────────────────────
header "Node.js not found — using minimal installer"
warn "Some features require the npx installer (agent copy, stack detection)"

# Check required tools
if ! command -v claude &>/dev/null; then
  fail "Claude CLI not found"
  echo "    Install: https://docs.anthropic.com/en/docs/claude-code/getting-started"
  exit 1
fi

# Check minimum Claude Code version (>=2.1.71 for GA agent teams)
CLAUDE_VER=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
if [ -n "$CLAUDE_VER" ]; then
  IFS='.' read -r CV_MAJOR CV_MINOR CV_PATCH <<< "$CLAUDE_VER"
  if [ "${CV_MAJOR:-0}" -lt 2 ] || \
     { [ "${CV_MAJOR:-0}" -eq 2 ] && [ "${CV_MINOR:-0}" -lt 1 ]; } || \
     { [ "${CV_MAJOR:-0}" -eq 2 ] && [ "${CV_MINOR:-0}" -eq 1 ] && [ "${CV_PATCH:-0}" -lt 71 ]; }; then
    warn "Claude Code v${CLAUDE_VER} — blitz requires >=2.1.71 for full functionality"
    warn "Multi-agent skills may not work. Update: npm install -g @anthropic-ai/claude-code@latest"
  else
    info "Claude Code v${CLAUDE_VER}"
  fi
fi

if ! command -v python3 &>/dev/null; then
  fail "python3 not found (required for settings merge)"
  exit 1
fi

if ! command -v git &>/dev/null; then
  fail "git not found"
  exit 1
fi

CLAUDE_HOME="$HOME/.claude"
CLAUDE_SETTINGS="$CLAUDE_HOME/settings.json"
PROJECT_DIR="${1:-$(pwd)}"
PROJECT_SETTINGS="$PROJECT_DIR/.claude/settings.json"

# ── Register marketplace ───────────────────────────────────────
header "Registering marketplace..."

python3 -c "
import json, os, sys

settings_path = '$CLAUDE_SETTINGS'
try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

if 'extraKnownMarketplaces' not in settings:
    settings['extraKnownMarketplaces'] = {}

if '$MARKETPLACE_NAME' in settings['extraKnownMarketplaces']:
    print('already registered')
    sys.exit(0)

settings['extraKnownMarketplaces']['$MARKETPLACE_NAME'] = {
    'source': {'source': 'git', 'url': '$REPO_URL'},
    'autoUpdate': True
}

os.makedirs(os.path.dirname(settings_path), exist_ok=True)
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
print('registered')
"

info "Marketplace registered"

# ── Install plugin ─────────────────────────────────────────────
header "Installing plugin..."
claude plugin install "${PLUGIN_NAME}@${MARKETPLACE_NAME}" 2>/dev/null || true
info "Plugin installed"

# ── Enable for project ─────────────────────────────────────────
header "Enabling plugin for project..."

mkdir -p "$PROJECT_DIR/.claude"

python3 -c "
import json, os

path = '$PROJECT_SETTINGS'
try:
    with open(path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

if '\$schema' not in settings:
    settings['\$schema'] = 'https://json.schemastore.org/claude-code-settings.json'

if 'enabledPlugins' not in settings:
    settings['enabledPlugins'] = {}

settings['enabledPlugins']['${PLUGIN_NAME}@${MARKETPLACE_NAME}'] = True

# Agent teams are GA as of Claude Code v2.1.71 (March 2026) — no experimental flag needed.
# Clean up legacy flag if present from previous install.
if 'env' in settings and 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' in settings.get('env', {}):
    del settings['env']['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS']
    if not settings['env']:
        del settings['env']

with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
"

info "Plugin enabled"
info "Agent teams: GA (no experimental flag needed)"

# ── Create .cc-sessions ───────────────────────────────────────
mkdir -p "$PROJECT_DIR/.cc-sessions"
info ".cc-sessions/ created"

# ── Add to .gitignore ─────────────────────────────────────────
GITIGNORE="$PROJECT_DIR/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if ! grep -q '.cc-sessions' "$GITIGNORE"; then
    echo -e "\n# Blitz session data\n.cc-sessions/" >> "$GITIGNORE"
    info "Added .cc-sessions/ to .gitignore"
  fi
else
  echo -e "# Blitz session data\n.cc-sessions/" > "$GITIGNORE"
  info "Created .gitignore"
fi

# ── Done ───────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}   ─── ⚡ ──────────────────────────────────${NC}"
echo ""
echo -e "   ${BYEL}Blitz installed!${NC}"
echo ""
echo -e "   Start: ${CYAN}claude${NC}"
echo -e "   Health: ${DIM}/blitz:health${NC}"
echo ""
echo -e "   ${DIM}Note: Run npx blitz-cc for full setup${NC}"
echo -e "   ${DIM}(permissions, agents, stack detection)${NC}"
echo ""
echo -e "${GREEN}   ──────────────────────────────── ⚡ ───${NC}"
echo ""
