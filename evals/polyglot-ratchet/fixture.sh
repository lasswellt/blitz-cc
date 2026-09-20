#!/usr/bin/env bash
# Scaffold: a repo with NO package.json — Python and Rust only, each with a real
# type error already present. Every eval before this one was Node-shaped, so a
# regression that made the loop Node-only again would have passed CI.
#
# `check --scope repo` must resolve this project's own checkers from the
# toolchain table (mypy, cargo check), report the diagnostics, and must NOT
# report the gates as passing or skipped-because-JS.
set -euo pipefail
git init -q .
git config user.email eval@example.com
git config user.name eval

cat > pyproject.toml <<'TOML'
[tool.mypy]
ignore_missing_imports = true
TOML
mkdir -p src py

cat > py/calc.py <<'PY'
def add(a: int, b: int) -> int:
    return a + b

def broken() -> int:
    return "this is not an int"
PY

cat > Cargo.toml <<'TOML'
[package]
name = "evalfix"
version = "0.1.0"
edition = "2021"
TOML

cat > src/lib.rs <<'RS'
pub fn add(a: i32, b: i32) -> i32 { a + b }
pub fn broken() -> i32 { missing_function() }
RS

mkdir -p .cc-sessions
git add -A
git commit -qm "base: python + rust, each with one type error"
