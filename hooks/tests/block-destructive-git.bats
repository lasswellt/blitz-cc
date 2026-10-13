#!/usr/bin/env bats
# Tests for hooks/scripts/block-destructive-git.sh

load '_helpers'

# block-destructive-git.sh uses 'is_dirty()' for some checks, which calls
# git status. The force-push guard to protected branches does NOT require
# a dirty tree; it always blocks. We test those directly.

@test "blocks git push --force to main" {
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push --force origin main")"
}

@test "blocks git push -f to master" {
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push -f origin master")"
}

@test "blocks git push --force-with-lease to main" {
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push --force-with-lease origin main")"
}

@test "allows git push origin HEAD (normal push)" {
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git push origin HEAD")"
}

@test "allows git push to feature branch" {
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git push origin feature/my-branch")"
}

@test "branch name with regex metachar does not falsely block" {
  # Branch name 'main|.*' should not match protected-branch check on a
  # git command that targets a different branch
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git branch -D some-other-branch")"
}

@test "allows non-git commands" {
  assert_allows "block-destructive-git.sh" "$(fake_tool_input "npm install")"
}

# ---------------------------------------------------------------------------
# SEC-R2-01 regression cases (HTC-2). The reset/checkout/clean/restore guards
# only fire on a DIRTY tree, and the branch-delete guard reads the current
# branch, so these run inside an isolated, dirty git repo on `main`.
# ---------------------------------------------------------------------------

# Stand up a throwaway repo with one committed file made dirty, on branch main.
make_dirty_repo() {
  REPO_DIR="$(mktemp -d)"
  cd "$REPO_DIR"
  git init -q
  git config user.email t@t.t
  git config user.name t
  git checkout -q -b main 2>/dev/null || true
  printf 'x\n' > f.txt
  git add f.txt
  git commit -qm init
  printf 'dirty\n' >> f.txt   # uncommitted change → is_dirty() true
}

teardown() {
  [ -n "${REPO_DIR:-}" ] && rm -rf "$REPO_DIR"
  return 0
}

@test "blocks git reset --hard with a global flag before the verb (dirty)" {
  make_dirty_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git -c core.pager=cat reset --hard")"
}

@test "blocks git clean with --no-pager global flag (dirty)" {
  make_dirty_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git --no-pager clean -fdx")"
}

@test "blocks git checkout . without -- (dirty)" {
  make_dirty_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git checkout .")"
}

@test "blocks git restore . (dirty)" {
  make_dirty_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git restore .")"
}

@test "allows git clean -fdn (dry-run) even when dirty" {
  make_dirty_repo
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git clean -fdn")"
}

@test "allows git restore --staged . (unstage, not discard)" {
  make_dirty_repo
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git restore --staged .")"
}

@test "allows git branch -D on a different branch while on main" {
  make_dirty_repo
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git branch -D feature-mainline")"
}

# Clean repo on main: only the push rule can fire (clean/reset need a dirty tree).
make_clean_repo() {
  make_dirty_repo
  git checkout -q -- f.txt
}

@test "allows push piped to tail followed by rm -f (flag is in another command)" {
  make_clean_repo
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git push -q origin HEAD 2>&1 | tail -1; rm -f x")"
}

@test "allows push to main followed by git clean -fd on a clean tree" {
  make_clean_repo
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git push origin main; git clean -fd")"
}

@test "blocks git push -f origin main (same command)" {
  make_clean_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push -f origin main")"
}

@test "blocks git push origin main --force (flag after branch)" {
  make_clean_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push origin main --force")"
}

@test "blocks git push --force-with-lease origin main" {
  make_clean_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push --force-with-lease origin main")"
}

@test "allows push origin HEAD && rm -f tmp" {
  make_clean_repo
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git push origin HEAD && rm -f tmp")"
}

@test "allows git -c x=y status (global flag, benign verb)" {
  make_dirty_repo
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git -c x=y status")"
}

# Quote-aware separator bound: a `;`, `&` or `|` inside quotes is argument text
# and must not end the push command, or a later --force slips through.
@test "blocks push with ';' inside a quoted push-option, then force" {
  make_clean_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push --push-option='a;b' --force origin main")"
}

@test "blocks push with '|' inside a quoted -o, force after branch" {
  make_clean_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push -o 'x|y' origin main --force")"
}

@test "blocks push with quoted '--force' flag" {
  make_clean_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push origin main '--force'")"
}

@test "blocks push with '&' inside a double-quoted -o, then -f" {
  make_clean_repo
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input 'git push -o "a&b" -f origin main')"
}

@test "blocks force-push in a command longer than the 8 KiB scan cap" {
  make_clean_repo
  local pad
  pad="$(printf 'a;%.0s' {1..4200})"
  assert_blocks "block-destructive-git.sh" \
    "$(fake_tool_input "git push -o '${pad}' --force origin main")"
}

# Fail-closed bound (fix round 5): the push/reset gap is unbounded unless a
# certain command break (outside quotes) sits between verb and flag. A
# redirection or an expansion holding `;&|` is not a break, so these block.
push_blocks() { make_clean_repo; assert_blocks "block-destructive-git.sh" "$(fake_tool_input "$1")"; }
push_allows() { make_clean_repo; assert_allows "block-destructive-git.sh" "$(fake_tool_input "$1")"; }
reset_blocks() { make_dirty_repo; assert_blocks "block-destructive-git.sh" "$(fake_tool_input "$1")"; }

@test "blocks push: redirection 2>&1 before trailing force" {
  push_blocks 'git push origin main 2>&1 --force'
}
@test "blocks push: redirection 2>&1 before force and refspec" {
  push_blocks 'git push 2>&1 --force origin main'
}
@test "blocks push: redirection 1>&2 before -f" {
  push_blocks 'git push origin 1>&2 -f main'
}
@test "blocks push: clobber redirection >| before force" {
  push_blocks 'git push origin main >| log --force'
}
@test "blocks push: ANSI-C quoted option holding ;" {
  push_blocks "git push -o \$'a\\';b' --force origin main"
}
@test "blocks push: quoted command substitution holding ;" {
  push_blocks 'git push -o "$(echo "a;b")" --force origin main'
}
@test "blocks push: bare command substitution holding ;" {
  push_blocks 'git push -o $(echo a;echo b) --force origin main'
}
@test "blocks push: backtick substitution holding ;" {
  push_blocks 'git push -o `echo a;echo b` --force origin main'
}
@test "blocks push: parameter expansion holding ;" {
  push_blocks 'git push -o ${U:-a;b} --force origin main'
}
@test "blocks push: arithmetic expansion holding |" {
  push_blocks 'git push -o $((1|2)) --force origin main'
}
@test "blocks push: second push in an && chain is itself forced" {
  push_blocks 'git push origin main && git push -f origin main'
}
@test "blocks push: newline inside a quoted option" {
  push_blocks "git push -o 'a
b' --force origin main"
}
@test "blocks push: backslash-newline continuation before force" {
  push_blocks 'git push origin main \
--force'
}
@test "blocks reset: redirection 2>&1 before --hard (dirty)" {
  reset_blocks 'git reset 2>&1 --hard HEAD~1'
}
@test "blocks reset: command substitution holding ; before --hard (dirty)" {
  reset_blocks 'git reset $(echo a;echo b) --hard'
}
@test "allows push to main piped to cat -f (pipe is a break)" {
  push_allows 'git push origin main | cat -f'
}
@test "allows push to main then rm -f on the next line" {
  push_allows 'git push origin main
rm -f x'
}
