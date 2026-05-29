# blitz-cc

Installer for **Blitz** — a holistic-machine Claude Code plugin for Vue/Nuxt + Firebase development.

```bash
npx blitz-cc@latest
```

One command detects your stack, registers the plugin + marketplace, configures permissions, wires the hooks, and copies typed agent definitions. `--yes` runs non-interactively.

## What it installs

Blitz turns Claude Code into an opinionated, partly-autonomous development environment:

- **37 skills** (`/blitz:*`) — research → sprint → ship pipeline, a consolidated `review`/`audit` quality surface over a shared check-registry, UI build, docs, release.
- **10 agents** — 6 builders (run in isolated git worktrees), 3 adversarial critics, 1 freeform-routing orchestrator.
- **37 hook scripts across 16 events** — including 7 anti-shortcut blockers that stop `--no-verify`, destructive git/SQL, test deletion, `as any` insertion, and type-error regressions at the tool boundary.
- **8-invariant quality ratchet** + optional Cross-Model Critic (Gemini).

## Usage

```bash
npx blitz-cc@latest            # interactive install
npx blitz-cc@latest --yes      # non-interactive
```

Bash fallback (no Node):

```bash
curl -fsSL https://raw.githubusercontent.com/lasswellt/blitz-cc/main/installer/install.sh | bash
```

## Requirements

- Claude Code ≥ 2.1.71 (orchestrator main-thread agent requires ≥ 2.1.117)
- Node.js ≥ 18, bash, python3, jq

## Links

- **Repository & docs:** https://github.com/lasswellt/blitz-cc
- **Changelog:** https://github.com/lasswellt/blitz-cc/blob/main/CHANGELOG.md

## License

MIT
