#!/usr/bin/env bash
set -euo pipefail

# Validate plugin directory structure and cross-references
# Usage: validate-plugin-structure.sh
# Exit 0 = pass, Exit 1 = fail
# Honors CLAUDE_PLUGIN_ROOT env var, otherwise defaults to parent of script dir.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

print_error()   { echo -e "  ${RED}FAIL${NC}: $*"; }
print_warning() { echo -e "  ${YELLOW}WARN${NC}: $*"; }
print_pass()    { echo -e "  ${GREEN}PASS${NC}: $*"; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

ERRORS=0
WARNINGS=0
CHECKS_PASSED=0

check_pass()    { CHECKS_PASSED=$((CHECKS_PASSED + 1)); print_pass "$*"; }
check_fail()    { ERRORS=$((ERRORS + 1)); print_error "$*"; }
check_warn()    { WARNINGS=$((WARNINGS + 1)); print_warning "$*"; }

# ---------------------------------------------------------------
# 1. plugin.json — exists, valid JSON, has required fields
# ---------------------------------------------------------------
echo "Checking plugin.json..."
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
if [[ ! -f "$PLUGIN_JSON" ]]; then
  check_fail "plugin.json not found at $PLUGIN_JSON"
else
  if ! python3 -m json.tool "$PLUGIN_JSON" > /dev/null 2>&1; then
    check_fail "plugin.json is not valid JSON"
  else
    check_pass "plugin.json is valid JSON"
    for field in name version description author; do
      if python3 -c "import json,sys; d=json.load(open('$PLUGIN_JSON')); sys.exit(0 if '$field' in d else 1)" 2>/dev/null; then
        check_pass "plugin.json has required field: $field"
      else
        check_fail "plugin.json missing required field: $field"
      fi
    done
  fi
fi

# ---------------------------------------------------------------
# 2. Skill directories — SKILL.md with name: and description:
# ---------------------------------------------------------------
echo "Checking skill directories..."
SKILLS_DIR="$PLUGIN_ROOT/skills"
if [[ -d "$SKILLS_DIR" ]]; then
  for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    [[ "$skill_name" == "_shared" ]] && continue

    skill_md="$skill_dir/SKILL.md"
    if [[ ! -f "$skill_md" ]]; then
      check_fail "skills/$skill_name: missing SKILL.md"
      continue
    fi

    # Check frontmatter for name: and description:
    frontmatter=$(sed -n '2,/^---$/p' "$skill_md" | head -n -1)
    if echo "$frontmatter" | grep -qP '^name:' 2>/dev/null; then
      check_pass "skills/$skill_name/SKILL.md has name: field"
    else
      check_fail "skills/$skill_name/SKILL.md missing name: in frontmatter"
    fi

    if echo "$frontmatter" | grep -qP '^description:' 2>/dev/null; then
      check_pass "skills/$skill_name/SKILL.md has description: field"
    else
      check_fail "skills/$skill_name/SKILL.md missing description: in frontmatter"
    fi
  done
else
  check_fail "skills/ directory not found"
fi

# ---------------------------------------------------------------
# 3. SKILL.md line limit — warn if > 500 lines
# ---------------------------------------------------------------
echo "Checking SKILL.md line limits..."
if [[ -d "$SKILLS_DIR" ]]; then
  for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    [[ -f "$skill_md" ]] || continue
    line_count=$(wc -l < "$skill_md")
    rel_path="${skill_md#"$PLUGIN_ROOT"/}"
    if [[ "$line_count" -gt 500 ]]; then
      check_warn "$rel_path exceeds 500 lines ($line_count lines)"
    else
      check_pass "$rel_path is within line limit ($line_count lines)"
    fi
  done
fi

# ---------------------------------------------------------------
# 4. Agent files — frontmatter with name:, description:, model:
# ---------------------------------------------------------------
echo "Checking agent files..."
AGENTS_DIR="$PLUGIN_ROOT/agents"
if [[ -d "$AGENTS_DIR" ]]; then
  for agent_file in "$AGENTS_DIR"/*.md; do
    [[ -f "$agent_file" ]] || continue
    agent_name=$(basename "$agent_file")

    frontmatter=$(sed -n '2,/^---$/p' "$agent_file" | head -n -1)
    for field in name description model; do
      if echo "$frontmatter" | grep -qP "^${field}:" 2>/dev/null; then
        check_pass "agents/$agent_name has $field: field"
      else
        check_fail "agents/$agent_name missing $field: in frontmatter"
      fi
    done
  done
else
  check_fail "agents/ directory not found"
fi

# ---------------------------------------------------------------
# 5. hooks.json — valid JSON, referenced scripts exist & executable
# ---------------------------------------------------------------
echo "Checking hooks.json..."
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
if [[ ! -f "$HOOKS_JSON" ]]; then
  check_fail "hooks/hooks.json not found"
else
  if ! python3 -m json.tool "$HOOKS_JSON" > /dev/null 2>&1; then
    check_fail "hooks.json is not valid JSON"
  else
    check_pass "hooks.json is valid JSON"

    # Walk every hook entry. Emits one tab-separated line per finding:
    #   CMD\t<command>            — script to resolve (shell form or exec form)
    #   SKIP\t<event>\t<type>     — non-command entry (prompt/agent), not validated
    #   BADIF\t<event>\t<value>   — `if` is not permission-rule shaped (Tool(pattern))
    #   OKIF\t<event>\t<value>
    #   BADTIMEOUT\t<event>\t<value>
    #   BADARGS\t<event>\t<value> — exec-form `args` must be an array of strings
    # Exec form (command = bare executable, args = literal list) must NOT wrap the
    # command in quotes; shell form ("${CLAUDE_PLUGIN_ROOT}"/... [flags]) may.
    hook_findings=$(python3 -c "
import json, re
data = json.load(open('$HOOKS_JSON'))
hooks = data.get('hooks', {})
IF_RX = re.compile(r'^[A-Za-z]+\(.+\)$')
for event_type in hooks:
    for matcher_block in hooks[event_type]:
        for hook in matcher_block.get('hooks', []):
            htype = hook.get('type', 'command')
            if htype != 'command':
                print('SKIP\t%s\t%s' % (event_type, htype)); continue
            cmd = hook.get('command', '')
            args = hook.get('args')
            if args is not None:
                if not isinstance(args, list) or not all(isinstance(a, str) for a in args):
                    print('BADARGS\t%s\t%r' % (event_type, args))
                elif cmd.startswith('\"'):
                    print('BADARGS\t%s\texec-form command must not be quoted: %s' % (event_type, cmd))
            if cmd:
                print('CMD\t%s' % cmd)
            cond = hook.get('if')
            if cond is not None:
                print(('OKIF' if isinstance(cond, str) and IF_RX.match(cond) else 'BADIF') + '\t%s\t%s' % (event_type, cond))
            to = hook.get('timeout')
            if to is not None and (isinstance(to, bool) or not isinstance(to, int) or to <= 0):
                print('BADTIMEOUT\t%s\t%r' % (event_type, to))
" 2>/dev/null || true)

    while IFS=$'\t' read -r kind a b; do
      [[ -z "$kind" ]] && continue
      case "$kind" in
        CMD)
          script_path="$a"
          # shell-form commands may carry flags (e.g. `foo.sh --all`); validate only the script token
          script_only="${script_path%% *}"
          # shell-form commands quote the var ("${CLAUDE_PLUGIN_ROOT}"/...) per Claude Code docs; strip quotes before resolving
          script_only="${script_only//\"/}"
          resolved="${script_only//\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_ROOT}"
          if [[ ! -f "$resolved" ]]; then
            check_fail "hooks.json references missing script: $script_path"
          elif [[ ! -x "$resolved" ]]; then
            check_fail "hooks.json references non-executable script: $script_path"
          else
            check_pass "hook script exists and is executable: $(basename "$resolved")"
          fi
          ;;
        SKIP)       check_pass "hooks.json $a: skipped non-command entry (type=$b)" ;;
        OKIF)       check_pass "hooks.json $a: if filter is permission-rule shaped ($b)" ;;
        BADIF)      check_fail "hooks.json $a: malformed if filter (expected Tool(pattern)): $b" ;;
        BADTIMEOUT) check_fail "hooks.json $a: timeout must be a positive integer (seconds): $b" ;;
        BADARGS)    check_fail "hooks.json $a: bad exec-form entry: $b" ;;
      esac
    done <<< "$hook_findings"
  fi
fi

# ---------------------------------------------------------------
# 7. Version consistency — marketplace.json vs plugin.json
# ---------------------------------------------------------------
echo "Checking version consistency..."
MARKETPLACE_JSON="$PLUGIN_ROOT/.claude-plugin/marketplace.json"
if [[ -f "$PLUGIN_JSON" && -f "$MARKETPLACE_JSON" ]]; then
  plugin_version=$(python3 -c "import json; print(json.load(open('$PLUGIN_JSON')).get('version',''))" 2>/dev/null || echo "")
  marketplace_version=$(python3 -c "
import json
data = json.load(open('$MARKETPLACE_JSON'))
plugins = data.get('plugins', [])
print(plugins[0].get('version','') if plugins else '')
" 2>/dev/null || echo "")

  if [[ -z "$plugin_version" || -z "$marketplace_version" ]]; then
    check_warn "Could not read version from plugin.json or marketplace.json"
  elif [[ "$plugin_version" != "$marketplace_version" ]]; then
    check_fail "Version mismatch: plugin.json=$plugin_version, marketplace.json=$marketplace_version"
  else
    check_pass "Version consistent across plugin.json and marketplace.json ($plugin_version)"
  fi
else
  check_warn "Cannot check version consistency — missing plugin.json or marketplace.json"
fi

# ---------------------------------------------------------------
# 8. Script shebangs — all .sh files have shebang and are executable
# ---------------------------------------------------------------
echo "Checking script shebangs and permissions..."
while IFS= read -r -d '' sh_file; do
  rel_path="${sh_file#"$PLUGIN_ROOT"/}"
  first_line=$(head -1 "$sh_file")
  if [[ "$first_line" == "#!/usr/bin/env bash" || "$first_line" == "#!/bin/bash" ]]; then
    check_pass "$rel_path has valid shebang"
  else
    check_fail "$rel_path missing shebang (got: $first_line)"
  fi

  case "$rel_path" in
    */_lib/*)
      # sourced libraries (never executed directly) — executable bit not required
      check_pass "$rel_path is a sourced lib (exec bit not required)" ;;
    *)
      if [[ -x "$sh_file" ]]; then
        check_pass "$rel_path is executable"
      else
        check_fail "$rel_path is not executable"
      fi ;;
  esac
done < <(find "$PLUGIN_ROOT" -name "*.sh" -not -path "*/.git/*" -print0 2>/dev/null)

# ---------------------------------------------------------------
# 9. Plugin workflows — workflows/*.js parse, meta literal first, no
#    resume-breaking calls (Date.now / Math.random / new Date() / import()).
#    Contract: skills/_shared/agents.md §Plugin workflows (E-045).
# ---------------------------------------------------------------
echo "Checking plugin workflows..."
WORKFLOWS_DIR="$PLUGIN_ROOT/workflows"
if [[ -d "$WORKFLOWS_DIR" ]]; then
  wf_count=0
  for wf in "$WORKFLOWS_DIR"/*.js; do
    [[ -f "$wf" ]] || continue
    wf_count=$((wf_count + 1))
    rel_path="${wf#"$PLUGIN_ROOT"/}"
    if command -v node >/dev/null 2>&1; then
      # The runtime evaluates a workflow inside an async wrapper, so top-level
      # await and top-level return are part of the contract. node --check on the
      # raw file detects the `export` as ESM and rejects both, so check the
      # wrapped form instead (reported line numbers shift by one).
      wf_dir=$(mktemp -d 2>/dev/null || mktemp -d -t blitz-wf)
      wf_tmp="$wf_dir/check.js"
      { printf '(async()=>{\n'; sed 's/^export[[:space:]]\+//' "$wf"; printf '\n})()\n'; } > "$wf_tmp"
      if node --check "$wf_tmp" >/dev/null 2>&1; then
        check_pass "$rel_path parses (node --check)"
      else
        check_fail "$rel_path has a syntax error (node --check): $(node --check "$wf_tmp" 2>&1 | grep -m1 -E 'Error' || true)"
      fi
      rm -rf "$wf_dir"
    else
      check_warn "$rel_path: node not found, skipping syntax check"
    fi
    # First statement must be the meta export (comments/blank lines may precede it).
    first_stmt=$(grep -vE '^\s*(//.*)?$' "$wf" | head -1)
    if [[ "$first_stmt" =~ ^export[[:space:]]+const[[:space:]]+meta[[:space:]]*= ]]; then
      check_pass "$rel_path starts with export const meta"
    else
      check_fail "$rel_path: first statement must be 'export const meta = {...}' (got: ${first_stmt:0:60})"
    fi
    if grep -nE 'Date\.now\(|Math\.random\(|new Date\(\)|import\(' "$wf" >/dev/null 2>&1; then
      check_fail "$rel_path uses a forbidden call (Date.now / Math.random / new Date() / import()): $(grep -nE 'Date\.now\(|Math\.random\(|new Date\(\)|import\(' "$wf" | head -1)"
    else
      check_pass "$rel_path has no resume-breaking calls"
    fi
  done
  [[ "$wf_count" -eq 0 ]] && check_warn "workflows/ exists but contains no *.js"
else
  check_pass "no workflows/ directory (optional)"
fi

# ---------------------------------------------------------------
# 10. Eval suite — every evals/**/case.yaml parses (python3 yaml when
#     available, else a shape check) and every prompt.md has a body.
#     Layout: https://code.claude.com/docs/en/plugin-evals
# ---------------------------------------------------------------
echo "Checking eval suite..."
EVALS_DIR="$PLUGIN_ROOT/evals"
if [[ -d "$EVALS_DIR" ]]; then
  HAVE_PYYAML=0
  python3 -c "import yaml" >/dev/null 2>&1 && HAVE_PYYAML=1
  while IFS= read -r -d '' cy; do
    rel_path="${cy#"$PLUGIN_ROOT"/}"
    if [[ "$HAVE_PYYAML" -eq 1 ]]; then
      if python3 -c "
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
assert isinstance(d, dict), 'not a mapping'
assert 'schema_version' in d and 'name' in d, 'missing schema_version or name'
" "$cy" >/dev/null 2>&1; then
        check_pass "$rel_path parses (schema_version + name present)"
      else
        check_fail "$rel_path does not parse or lacks schema_version/name"
      fi
    else
      if grep -qE '^schema_version:' "$cy" && grep -qE '^name:' "$cy" && ! grep -qP '\t' "$cy"; then
        check_pass "$rel_path shape ok (no PyYAML: schema_version + name, no tabs)"
      else
        check_fail "$rel_path shape check failed (needs schema_version: and name:, no tabs)"
      fi
    fi
  done < <(find "$EVALS_DIR" -name case.yaml -not -path "*/results/*" -print0 2>/dev/null)

  while IFS= read -r -d '' pm; do
    rel_path="${pm#"$PLUGIN_ROOT"/}"
    # body = everything after the closing frontmatter fence (or the whole file when none)
    body=$(awk 'BEGIN{fm=0} NR==1 && /^---$/ {fm=1; next} fm==1 && /^---$/ {fm=2; next} fm!=1 {print}' "$pm" | grep -vE '^\s*$' || true)
    if [[ -n "$body" ]]; then
      check_pass "$rel_path has a prompt body"
    else
      check_fail "$rel_path has an empty prompt body"
    fi
    # frontmatter must parse: an unquoted "key: value: more" description makes the
    # runner refuse the whole suite ("invalid YAML frontmatter"), not just the case.
    if head -1 "$pm" | grep -qx -- '---'; then
      fm=$(awk 'NR==1 && /^---$/ {fm=1; next} fm==1 && /^---$/ {exit} fm==1 {print}' "$pm")
      if [[ "$HAVE_PYYAML" -eq 1 ]]; then
        if printf '%s\n' "$fm" | python3 -c "import sys, yaml; d = yaml.safe_load(sys.stdin); assert isinstance(d, dict)" >/dev/null 2>&1; then
          check_pass "$rel_path frontmatter parses"
        else
          check_fail "$rel_path frontmatter does not parse as YAML (quote descriptions that contain ': ')"
        fi
      elif printf '%s\n' "$fm" | grep -qE '^description: [^"'"'"'].*: '; then
        check_fail "$rel_path description contains ': ' and is unquoted (YAML parse error at run time)"
      fi
    fi
  done < <(find "$EVALS_DIR" -name prompt.md -not -path "*/results/*" -print0 2>/dev/null)

  case_count=$(find "$EVALS_DIR" -mindepth 2 \( -name prompt.md -o -name case.yaml \) -not -path "*/results/*" -printf '%h\n' 2>/dev/null | sort -u | wc -l)
  if [[ "$case_count" -gt 0 ]]; then
    check_pass "evals/ contains $case_count case(s)"
  else
    check_warn "evals/ exists but contains no cases (prompt.md or case.yaml)"
  fi
else
  check_pass "no evals/ directory (optional)"
fi

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo ""
TOTAL=$((CHECKS_PASSED + ERRORS))
if [[ "$ERRORS" -eq 0 ]]; then
  echo -e "${GREEN}PASS${NC}: $CHECKS_PASSED checks passed, 0 errors, $WARNINGS warnings"
  exit 0
else
  echo -e "${RED}FAIL${NC}: $ERRORS errors, $WARNINGS warnings (out of $TOTAL checks)"
  exit 1
fi
