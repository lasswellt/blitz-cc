#!/usr/bin/env bats
# Tests for hooks/scripts/block-destructive-git.sh

load '_helpers'

# block-destructive-git.sh uses 'is_dirty()' for some checks, which calls
# git status. The force-push guard to protected branches does NOT require
# a dirty tree — it always blocks. We test those directly.

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
# branch — so these run inside an isolated, dirty git repo on `main`.
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

@test "allows git -c x=y status (global flag, benign verb)" {
  make_dirty_repo
  assert_allows "block-destructive-git.sh" \
    "$(fake_tool_input "git -c x=y status")"
}
