#!/usr/bin/env bats
# Parity table for hooks/scripts/block-destructive-git.sh against the guard as
# it stood at 57e6247, before the force-push bound was narrowed (plan `fixes`,
# T-008). Narrowing the match to stop `git push …; rm -f x` false positives
# reopened bypasses twice (quoted separators, then redirections and
# expansions), so every candidate here must stay blocked wherever the old
# guard blocked it. A candidate the old guard also allowed is a pre-existing
# gap, not a regression; the table still runs it so a later fix can flip it.
# Requires: bats-core, git

load '_helpers'

BASE_REF=57e6247

setup_file() {
  local repo; repo="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export PARITY_DIR="$BATS_FILE_TMPDIR/base-hook"
  mkdir -p "$PARITY_DIR"
  git -C "$repo" show "$BASE_REF:hooks/scripts/block-destructive-git.sh" > "$PARITY_DIR/block-destructive-git.sh"
  ln -s "$repo/hooks/scripts/_lib" "$PARITY_DIR/_lib"
  export HEAD_HOOK="$repo/hooks/scripts/block-destructive-git.sh"
  export BASE_HOOK="$PARITY_DIR/block-destructive-git.sh"
}

# A dirty repo on main, so the reset guards fire as well as the push guards.
setup() {
  REPO_DIR="$(mktemp -d)"
  cd "$REPO_DIR"
  git init -q
  git config user.email t@t.t
  git config user.name t
  git checkout -q -b main 2>/dev/null || true
  printf 'x\n' > f.txt
  git add f.txt
  git commit -qm init
  printf 'y\n' > f.txt
}
teardown() { cd /; rm -rf "$REPO_DIR"; }

# verdict <hook> <command>: prints "block" (exit 2) or "allow".
verdict() {
  local rc=0
  fake_tool_input "$2" | bash "$1" >/dev/null 2>&1 || rc=$?
  [ "$rc" -eq 2 ] && echo block || echo allow
}

# parity <command>: fail when the old guard blocked and the current one allows.
parity() {
  local b h
  b=$(verdict "$BASE_HOOK" "$1"); h=$(verdict "$HEAD_HOOK" "$1")
  if [ "$b" = block ] && [ "$h" = allow ]; then
    echo "regression: base=$b head=$h :: $1"; return 1
  fi
}

@test "parity: function wrapper defined in the same line" {
  parity 'f(){ git push "$@"; }; f --force origin main'
}
@test "parity: function keyword wrapper" {
  parity 'function f { git push "$@"; }; f --force origin main'
}
@test "parity: alias wrapper" { parity "alias gp='git push'; gp --force origin main"; }
@test "parity: git -C . push --force" { parity 'git -C . push --force origin main'; }
@test "parity: command git push --force" { parity 'command git push --force origin main'; }
@test "parity: exec git push --force" { parity 'exec git push --force origin main'; }
@test "parity: eval git push --force" { parity 'eval git push --force origin main'; }
@test "parity: xargs supplies the flag" { parity 'echo --force | xargs git push origin main'; }
@test "parity: env prefix" { parity 'GIT_DIR=.git git push --force origin main'; }
@test "parity: +refspec force" { parity 'git push origin +main'; }
@test "parity: |& after the flag" { parity 'git push --force origin main |& cat'; }
@test "parity: &> redirection after the flag" { parity 'git push --force origin main &> /dev/null'; }
@test "parity: &> redirection before the flag" { parity 'git push origin main &> /dev/null --force'; }
@test "parity: quoted ; adjacent to the flag" { parity "git push origin main ';' --force"; }
@test "parity: tab before the flag" { parity "$(printf 'git push origin main\t--force')"; }
@test "parity: repeated spaces" { parity 'git  push   --force   origin  main'; }
@test "parity: --force-with-lease=ref" { parity 'git push origin main --force-with-lease=main'; }
@test "parity: double-quoted break then flag" { parity 'git push origin main "&&" --force'; }
@test "parity: break inside a subshell group" { parity '(git push origin main; true) --force'; }
@test "parity: brace group" { parity '{ git push --force origin main; }'; }
@test "parity: semicolon inside an assignment value" { parity 'X="a;b" git push --force origin main'; }
@test "parity: 2>&1 then pipe then flag in the same push" { parity 'git push origin main 2>&1|cat --force'; }
@test "parity: reset --hard via git -C" { parity 'git -C . reset --hard'; }
@test "parity: reset --hard via command" { parity 'command git reset --hard'; }
@test "parity: reset with redirection before --hard" { parity 'git reset HEAD 2>/dev/null --hard'; }
@test "parity: reset --hard after a quoted ;" { parity "git reset ';' --hard"; }
