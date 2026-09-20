#!/usr/bin/env bats
# Tests for hooks/scripts/post-edit-typecheck-block.sh (PostToolUse on Write|Edit)
# Blocks when the typecheck diagnostic count REGRESSES vs the stored baseline.
# The checker comes from the toolchain table's `typecheck` lane, so this suite
# covers the TypeScript row; toolchain.bats covers the language-agnostic path.
# Env opt-out the hook actually reads: BLITZ_DISABLE_TYPECHECK_BLOCK=1.
#
# The BLOCK test stands up a throwaway TS project and shims `npx`/`tsc` on PATH
# (real tsc is not installed in BATS_TEST_TMPDIR) so the typecheck run is fast
# and deterministic. The hook also short-circuits when CI=true, so the block
# test explicitly unsets CI.

load '_helpers'

# Build a PostToolUse Edit payload for a TS file.
fake_ts_edit() {
  jq -n --arg fp "$1" \
    '{"tool_name":"Edit","tool_input":{"file_path":$fp},"session_id":"test-session"}'
}

# Stand up a minimal TS project with a baseline of 0 errors and a fake tsc that
# reports one error for $FP. Exports REPO_DIR and FP for the test body.
make_ts_project_with_error() {
  REPO_DIR="$(mktemp -d)"
  cd "$REPO_DIR"
  printf '{ "compilerOptions": { "strict": true, "noEmit": true } }\n' > tsconfig.json
  printf 'const n: number = "x";\n' > bad.ts
  FP="$REPO_DIR/bad.ts"
  mkdir -p .cc-sessions
  printf '{"schema_version":1,"error_count":0,"updated":"2020-01-01T00:00:00Z","complete":true}\n' \
    > .cc-sessions/typecheck-baseline.json
  mkdir -p fakebin
  cat > fakebin/npx <<EOF
#!/usr/bin/env bash
# Stub: --no-install <tool> [flags]. vue-tsc unavailable -> hook uses plain tsc.
tool=""
for a in "\$@"; do case "\$a" in --no-install|-*) ;; *) tool="\$a"; break;; esac; done
case "\$tool" in
  vue-tsc) exit 1 ;;
  tsc)
    # The toolchain resolver probes a row's tool with --version before using
    # it; a real \`npx tsc --version\` prints a version and exits 0.
    if printf '%s\n' "\$@" | grep -q -- '--version'; then echo "5.9.0"; exit 0; fi
    if printf '%s\n' "\$@" | grep -q -- '--listFilesOnly'; then echo "$FP"; exit 0; fi
    echo "$FP:1:7 - error TS2322: Type 'string' is not assignable to type 'number'."
    exit 1 ;;
  *) exit 1 ;;
esac
EOF
  chmod +x fakebin/npx
}

teardown() {
  [ -n "${REPO_DIR:-}" ] && rm -rf "$REPO_DIR"
  return 0
}

@test "blocks an edit that regresses the tsc error count (0 -> 1)" {
  make_ts_project_with_error
  local status=0
  CI="" PATH="$REPO_DIR/fakebin:$PATH" bash -c \
    'printf "%s" "$1" | bash "$2"' _ "$(fake_ts_edit "$FP")" \
    "$HOOKS_DIR/post-edit-typecheck-block.sh" >/dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ]
}

@test "allows the same edit when BLITZ_DISABLE_TYPECHECK_BLOCK=1" {
  # Confirms the hook reads the documented opt-out env var (early exit before tsc).
  make_ts_project_with_error
  local status=0
  CI="" BLITZ_DISABLE_TYPECHECK_BLOCK=1 PATH="$REPO_DIR/fakebin:$PATH" bash -c \
    'printf "%s" "$1" | bash "$2"' _ "$(fake_ts_edit "$FP")" \
    "$HOOKS_DIR/post-edit-typecheck-block.sh" >/dev/null 2>&1 || status=$?
  [ "$status" -eq 0 ]
}

@test "allows edits to non-TS files (out of scope)" {
  assert_allows "post-edit-typecheck-block.sh" \
    "$(fake_ts_edit "$BATS_TEST_TMPDIR/readme.md")"
}

@test "allows when no typecheck row resolves (no TS project markers)" {
  # Run from a clean temp dir with no tsconfig — hook exits 0 before any tsc work.
  local d; d="$(mktemp -d)"
  local status=0
  ( cd "$d" && CI="" printf '%s' "$(fake_ts_edit "$d/x.ts")" \
      | bash "$HOOKS_DIR/post-edit-typecheck-block.sh" >/dev/null 2>&1 ) || status=$?
  rm -rf "$d"
  [ "$status" -eq 0 ]
}
