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

    # Extract script paths, replacing ${CLAUDE_PLUGIN_ROOT} with actual root
    script_paths=$(python3 -c "
import json, sys
data = json.load(open('$HOOKS_JSON'))
hooks = data.get('hooks', {})
for event_type in hooks:
    for matcher_block in hooks[event_type]:
        for hook in matcher_block.get('hooks', []):
            cmd = hook.get('command', '')
            if cmd:
                print(cmd)
" 2>/dev/null || true)

    while IFS= read -r script_path; do
      [[ -z "$script_path" ]] && continue
      # hooks.json `command` may include args (e.g. `foo.sh --all`); validate only the script token
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
    done <<< "$script_paths"
  fi
fi

# ---------------------------------------------------------------
# 6. README cross-reference — compare counts
# ---------------------------------------------------------------
echo "Checking README cross-references..."
README="$PLUGIN_ROOT/README.md"
if [[ -f "$README" ]]; then
  # Count actual skill dirs (excluding _shared)
  actual_skills=0
  if [[ -d "$SKILLS_DIR" ]]; then
    for d in "$SKILLS_DIR"/*/; do
      name=$(basename "$d")
      [[ "$name" == "_shared" ]] && continue
      actual_skills=$((actual_skills + 1))
    done
  fi

  # Count actual agent files
  actual_agents=0
  if [[ -d "$AGENTS_DIR" ]]; then
    for f in "$AGENTS_DIR"/*.md; do
      [[ -f "$f" ]] && actual_agents=$((actual_agents + 1))
    done
  fi

  # Check README for "**N skills**" pattern (README.md:14 format)
  readme_skills=$(grep -oP '\*\*\K\d+(?= skills\*\*)' "$README" 2>/dev/null | head -1 || echo "")
  if [[ -n "$readme_skills" && "$readme_skills" -ne "$actual_skills" ]]; then
    check_fail "README says $readme_skills skills but found $actual_skills skill directories"
  elif [[ -n "$readme_skills" ]]; then
    check_pass "README skill count matches ($actual_skills)"
  fi

  # Check README for "**N agents**" pattern (README.md:14 format)
  readme_agents=$(grep -oP '\*\*\K\d+(?= agents\*\*)' "$README" 2>/dev/null | head -1 || echo "")
  if [[ -n "$readme_agents" && "$readme_agents" -ne "$actual_agents" ]]; then
    check_fail "README says $readme_agents agents but found $actual_agents agent files"
  elif [[ -n "$readme_agents" ]]; then
    check_pass "README agent count matches ($actual_agents)"
  fi
else
  check_warn "README.md not found, skipping cross-reference check"
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
