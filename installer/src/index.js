'use strict';

const fs = require('fs');
const path = require('path');
const { VERSION, PLUGIN_KEY } = require('./constants');
const ui = require('./ui');
const { read, write, ensureDir, mergePermissions, setNestedValue, getNestedValue } = require('./settings');
const { detectEnvironment } = require('./detect');
const { detectStack, formatStack } = require('./stack');
const { generatePermissions } = require('./permissions');
const { registerMarketplace } = require('./marketplace');
const { installPlugin, enablePlugin } = require('./plugin');
const { copyAgents } = require('./agents');
const { verify } = require('./verify');
const { uninstall } = require('./uninstall');

function parseArgs(argv) {
  const args = argv.slice(2);
  const opts = {
    project: process.cwd(),
    yes: false,
    dryRun: false,
    verbose: false,
    skipAgents: false,
    skipPermissions: false,
    showHelp: false,
    showVersion: false,
    doUninstall: false,
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--project':     opts.project = path.resolve(args[++i] || '.'); break;
      case '--yes': case '-y': opts.yes = true; break;
      case '--dry-run':     opts.dryRun = true; break;
      case '--verbose':     opts.verbose = true; break;
      case '--skip-agents': opts.skipAgents = true; break;
      case '--skip-permissions': opts.skipPermissions = true; break;
      case '--help': case '-h': opts.showHelp = true; break;
      case '--version': case '-v': opts.showVersion = true; break;
      case '--uninstall':   opts.doUninstall = true; break;
    }
  }

  return opts;
}

function showHelp() {
  console.log(`
  ${ui.color.bold}blitz-cc${ui.color.reset} — Installer for the Blitz Claude Code plugin

  ${ui.color.bold}Usage:${ui.color.reset}
    npx blitz-cc@latest              Interactive install for current project
    npx blitz-cc@latest --yes        Non-interactive with defaults
    npx blitz-cc@latest --uninstall  Remove Blitz from project

  ${ui.color.bold}Options:${ui.color.reset}
    --project <path>     Target project directory (default: cwd)
    --yes, -y            Accept all defaults (non-interactive)
    --dry-run            Preview changes without writing
    --skip-agents        Skip agent copy step
    --skip-permissions   Skip permissions setup
    --uninstall          Remove Blitz from the project
    --verbose            Show detailed output
    --version, -v        Show version
    --help, -h           Show this help

  ${ui.color.bold}Examples:${ui.color.reset}
    ${ui.color.dim}# Install for current project${ui.color.reset}
    npx blitz-cc@latest

    ${ui.color.dim}# Install for a specific project, non-interactive${ui.color.reset}
    npx blitz-cc@latest --project ~/my-app --yes

    ${ui.color.dim}# Preview what would change${ui.color.reset}
    npx blitz-cc@latest --dry-run

    ${ui.color.dim}# Uninstall${ui.color.reset}
    npx blitz-cc@latest --uninstall
`);
}

async function run(argv) {
  const opts = parseArgs(argv);

  if (opts.showVersion) {
    console.log(VERSION);
    return;
  }

  if (opts.showHelp) {
    showHelp();
    return;
  }

  // Banner
  ui.banner();

  if (opts.dryRun) {
    console.log(`  ${ui.color.yellow}DRY RUN${ui.color.reset} — no files will be modified\n`);
  }

  // Uninstall path
  if (opts.doUninstall) {
    await uninstall(opts.project, opts);
    return;
  }

  // ── Phase 0: Environment Detection ─────────────────────────────
  ui.header('Checking environment...');
  const env = detectEnvironment();

  const envItems = [
    ui.treeItem('Claude CLI', env.claude ? `v${env.claude.version} at ${env.claude.path}` : null, !!env.claude),
    ui.treeItem('Node.js',    env.node.version,    !!env.node.path),
    ui.treeItem('python3',    env.python3.version,  !!env.python3.path),
    ui.treeItem('bash',       env.bash.version,     !!env.bash.path),
    ui.treeItem('git',        env.git.version,      !!env.git.path),
    ui.treeItem('jq',         env.jq.version || 'not found', !!env.jq.path),
    ui.treeItem('Platform',   `${process.platform}${env.wsl ? ' (WSL)' : ''}`),
  ];

  // Show existing install status
  if (env.existing.pluginInstalled) {
    envItems.push(ui.treeItem('Existing install', `v${env.existing.installedVersion} (update)`));
  } else {
    envItems.push(ui.treeItem('Existing install', 'Not found (fresh install)'));
  }

  ui.tree(envItems);

  // Check required deps
  if (!env.claude) {
    console.log('');
    ui.fail('Claude CLI not found');
    ui.info('Install: https://docs.anthropic.com/en/docs/claude-code/getting-started');
    ui.info('Then re-run: npx blitz-cc@latest');
    process.exit(1);
  }

  // Check minimum Claude Code version (>=2.1.71 for GA agent teams)
  if (env.claude && env.claude.version) {
    const parts = env.claude.version.split('.').map(Number);
    const [major, minor, patch] = parts;
    const MIN_MAJOR = 2, MIN_MINOR = 1, MIN_PATCH = 71;
    const meetsMinimum = major > MIN_MAJOR ||
      (major === MIN_MAJOR && minor > MIN_MINOR) ||
      (major === MIN_MAJOR && minor === MIN_MINOR && (patch || 0) >= MIN_PATCH);
    if (!meetsMinimum) {
      console.log('');
      ui.warn(`Claude Code v${env.claude.version} detected — blitz requires >=2.1.71 for full functionality`);
      ui.info('Multi-agent skills (sprint-dev, research, etc.) may not work correctly.');
      ui.info('Update: npm install -g @anthropic-ai/claude-code@latest');
    }
  }
  if (!env.node.path) {
    console.log('');
    ui.fail('Node.js not found (required for hooks)');
    process.exit(1);
  }
  if (!env.python3.path) {
    console.log('');
    ui.warn('python3 not found — some hooks may not work correctly');
  }

  // ── Phase 1: Project Selection ─────────────────────────────────
  let projectDir = opts.project;

  if (!opts.yes) {
    const hasPkg = fs.existsSync(path.join(projectDir, 'package.json'));
    const hasClaude = fs.existsSync(path.join(projectDir, '.claude'));

    ui.header('Project');
    ui.tree([
      ui.treeItem('Directory', projectDir),
      ui.treeItem('package.json', hasPkg ? 'found' : 'not found', hasPkg),
      ui.treeItem('.claude/', hasClaude ? 'exists' : 'will be created', hasClaude),
    ]);

    const confirmed = await ui.prompt('Install Blitz for this project?', true);
    if (!confirmed) {
      projectDir = await ui.promptPath('Enter project path', projectDir);
    }
  }

  if (!fs.existsSync(projectDir)) {
    ui.fail(`Project directory not found: ${projectDir}`);
    process.exit(1);
  }

  // ── Phase 2: Stack Detection ───────────────────────────────────
  ui.header('Stack detection...');
  const stack = detectStack(projectDir);
  const stackItems = formatStack(stack);
  ui.tree(stackItems.map((s) => {
    const [label, value] = s.split(': ');
    return ui.treeItem(label, value);
  }));

  // ── Phase 3: Marketplace Registration ──────────────────────────
  ui.header('Marketplace registration...');
  // Auto-update opt-in. Off-by-default because enabling authorizes Claude Code
  // to pull plugin updates (incl. hook scripts that run as the user's OS
  // process) from upstream on every session start — a supply-chain trust
  // relationship the user must explicitly enter into.
  // Honors `--yes` (non-interactive: keep default off) and `BLITZ_AUTO_UPDATE=1`
  // (env-var explicit opt-in).
  if (opts.autoUpdate === undefined) {
    if (process.env.BLITZ_AUTO_UPDATE === '1') {
      opts.autoUpdate = true;
      ui.info('Auto-update enabled via BLITZ_AUTO_UPDATE=1');
    } else if (!opts.yes && process.stdin.isTTY && process.stdout.isTTY) {
      opts.autoUpdate = await ui.prompt(
        'Enable automatic upstream updates from GitHub? (pulls hook scripts on every session)',
        false
      );
    } else {
      opts.autoUpdate = false;
    }
  }
  registerMarketplace(opts);

  // ── Phase 4: Plugin Installation ───────────────────────────────
  ui.header('Plugin installation...');
  const installed = installPlugin(env.claude.path, opts);
  if (!installed && !opts.dryRun) {
    ui.warn('Continuing with remaining setup steps...');
  }

  // ── Phase 5: Plugin Enablement ─────────────────────────────────
  ui.header('Plugin enablement...');
  enablePlugin(projectDir, opts);

  // ── Phase 6: Permissions Setup ─────────────────────────────────
  if (!opts.skipPermissions) {
    ui.header('Permissions setup...');
    const permissions = generatePermissions(stack);
    const settingsPath = path.join(projectDir, '.claude', 'settings.json');
    const settings = read(settingsPath);

    // Ensure $schema
    if (!settings.$schema) {
      settings.$schema = 'https://json.schemastore.org/claude-code-settings.json';
    }

    const existingAllow = settings.permissions?.allow || [];

    if (!opts.yes && !opts.dryRun) {
      console.log(`\n    ${ui.color.bold}Allow permissions:${ui.color.reset}`);
      ui.permissionDiff(existingAllow, permissions.allow);
      console.log(`\n    ${ui.color.bold}Deny rules:${ui.color.reset}`);
      ui.permissionDiff(settings.permissions?.deny || [], permissions.deny);

      const applyPerms = await ui.prompt('Apply these permissions?', true);
      if (!applyPerms) {
        ui.info('Permissions skipped');
        permissions.allow = [];
        permissions.deny = [];
      }
    }

    if (permissions.allow.length > 0 || permissions.deny.length > 0) {
      mergePermissions(settings, permissions);

      if (opts.dryRun) {
        ui.info(`Would add ${permissions.allow.length} allow and ${permissions.deny.length} deny permissions`);
      } else {
        write(settingsPath, settings);
        ui.success(`Permissions configured (${settings.permissions.allow.length} allow, ${settings.permissions.deny.length} deny)`);
      }
    }
  }

  // ── Phase 7: Environment Variables ─────────────────────────────
  ui.header('Environment variables...');
  const settingsPath = path.join(projectDir, '.claude', 'settings.json');
  const envSettings = read(settingsPath);

  if (!envSettings.$schema) {
    envSettings.$schema = 'https://json.schemastore.org/claude-code-settings.json';
  }

  // Agent teams are GA as of Claude Code v2.1.71 (March 2026).
  // Clean up the experimental flag if it was set by a previous install.
  const currentVal = getNestedValue(envSettings, 'env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS');
  if (currentVal === '1') {
    if (opts.dryRun) {
      ui.info('Would remove legacy CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS flag (agent teams are now GA)');
    } else {
      delete envSettings.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS;
      if (envSettings.env && Object.keys(envSettings.env).length === 0) {
        delete envSettings.env;
      }
      write(settingsPath, envSettings);
      ui.success('Removed legacy CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS flag (agent teams are now GA)');
    }
  } else {
    ui.success('Agent teams: GA (no experimental flag needed)');
  }

  // ── Phase 8: Agent Setup ───────────────────────────────────────
  if (!opts.skipAgents) {
    ui.header('Agent setup...');
    ui.info('Blitz agents can be copied to .claude/agents/ for auto-accept mode.');
    ui.info('This eliminates permission prompts when agents edit files.');

    let shouldCopy = opts.yes; // Default: copy in --yes mode
    if (!opts.yes && !opts.dryRun) {
      shouldCopy = await ui.prompt('Copy agents with acceptEdits mode?', false);
    }

    if (shouldCopy) {
      copyAgents(projectDir, opts);
    } else {
      ui.info('Agent copy skipped');
    }
  }

  // ── Phase 9: Activity Feed Setup ───────────────────────────────
  ui.header('Activity feed setup...');
  const sessionsDir = path.join(projectDir, '.cc-sessions');

  if (opts.dryRun) {
    ui.info('Would create .cc-sessions/');
  } else {
    ensureDir(sessionsDir);
    ui.success('.cc-sessions/ directory ready');
  }

  // Add to .gitignore
  const gitignorePath = path.join(projectDir, '.gitignore');
  if (fs.existsSync(gitignorePath)) {
    const gitignore = fs.readFileSync(gitignorePath, 'utf-8');
    if (!gitignore.includes('.cc-sessions')) {
      if (opts.dryRun) {
        ui.info('Would add .cc-sessions/ to .gitignore');
      } else {
        fs.appendFileSync(gitignorePath, '\n# Blitz session data\n.cc-sessions/\n');
        ui.success('Added .cc-sessions/ to .gitignore');
      }
    }
  } else if (!opts.dryRun) {
    fs.writeFileSync(gitignorePath, '# Blitz session data\n.cc-sessions/\n');
    ui.success('Created .gitignore with .cc-sessions/');
  }

  // ── Phase 10: Verification ─────────────────────────────────────
  if (!opts.dryRun) {
    verify(projectDir);
  }

  // ── Success ────────────────────────────────────────────────────
  const bcyn = '\x1b[96m';
  console.log(`
${ui.color.green}   ─── ${ui.sym.bolt} ──────────────────────────────────${ui.color.reset}

   ${ui.color.bold}${ui.color.yellow}${ui.sym.bolt} Blitz installed successfully!${ui.color.reset}

   Start a new Claude Code session to begin:
     ${ui.color.cyan}$ claude${ui.color.reset}

   Quick start:
     ${ui.color.dim}/blitz:health${ui.color.reset}       ${ui.sym.arrow} Verify plugin health
     ${ui.color.dim}/blitz:ask${ui.color.reset}          ${ui.sym.arrow} Ask Blitz anything
     ${ui.color.dim}/blitz:next${ui.color.reset}         ${ui.sym.arrow} What should I work on?
     ${ui.color.dim}/blitz:codebase-map${ui.color.reset} ${ui.sym.arrow} Map your codebase

   All 37 skills: ${ui.color.cyan}/blitz:<TAB>${ui.color.reset}
   Docs: ${ui.color.dim}https://github.com/lasswellt/blitz-cc${ui.color.reset}

${ui.color.green}   ──────────────────────────────── ${ui.sym.bolt} ───${ui.color.reset}
`);
}

module.exports = { run };
