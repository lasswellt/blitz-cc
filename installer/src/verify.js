'use strict';

const fs = require('fs');
const path = require('path');
const { CLAUDE_SETTINGS, INSTALLED_PLUGINS, MARKETPLACE_NAME, PLUGIN_KEY } = require('./constants');
const { read, getNestedValue } = require('./settings');
const { success, fail, warn, header, color, sym } = require('./ui');
const { detectEnvironment } = require('./detect');

function verify(projectDir) {
  header('Verification');
  let passed = 0;
  let failed = 0;

  // 1. Marketplace registered
  const globalSettings = read(CLAUDE_SETTINGS);
  if (getNestedValue(globalSettings, `extraKnownMarketplaces.${MARKETPLACE_NAME}`)) {
    success(`Marketplace registered in ~/.claude/settings.json`);
    passed++;
  } else {
    fail('Marketplace not registered');
    failed++;
  }

  // 2. Plugin installed
  const plugins = read(INSTALLED_PLUGINS);
  const entries = plugins?.plugins?.[PLUGIN_KEY] || plugins?.plugins?.['cc-plugin-suite@cc-plugin-suite'];
  if (entries && entries.length > 0) {
    success(`Plugin installed (v${entries[0].version})`);
    passed++;
  } else {
    fail('Plugin not found in installed_plugins.json');
    failed++;
  }

  // 3. Plugin enabled
  const projectSettings = read(path.join(projectDir, '.claude', 'settings.json'));
  const enabled = getNestedValue(projectSettings, `enabledPlugins.${PLUGIN_KEY}`)
    || getNestedValue(projectSettings, 'enabledPlugins.cc-plugin-suite@cc-plugin-suite');
  if (enabled) {
    success('Plugin enabled in project settings');
    passed++;
  } else {
    fail('Plugin not enabled in .claude/settings.json');
    failed++;
  }

  // 4. Permissions configured
  const perms = projectSettings?.permissions;
  if (perms && perms.allow && perms.allow.length > 0) {
    success(`Permissions configured (${perms.allow.length} allow, ${(perms.deny || []).length} deny)`);
    passed++;
  } else {
    warn('No permissions configured');
  }

  // 5. Legacy agent-teams flag (blitz does not use agent teams; the flag only adds token cost)
  const env = projectSettings?.env;
  if (env && env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS === '1') {
    warn('Legacy CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS flag still set — run installer to clean up');
  } else {
    success('No legacy agent-teams flag');
    passed++;
  }

  // 6. Hook dependencies
  const env_info = detectEnvironment();
  const hookDeps = [
    { name: 'bash',    ok: !!env_info.bash.path },
    { name: 'python3', ok: !!env_info.python3.path },
    { name: 'npx',     ok: !!env_info.node.path },
  ];

  const allHookDeps = hookDeps.every((d) => d.ok);
  if (allHookDeps) {
    success('Hook dependencies available (bash, python3, npx)');
    passed++;
  } else {
    const missing = hookDeps.filter((d) => !d.ok).map((d) => d.name);
    warn(`Missing hook dependencies: ${missing.join(', ')}`);
  }

  // 7. .cc-sessions
  if (fs.existsSync(path.join(projectDir, '.cc-sessions'))) {
    success('.cc-sessions/ directory exists');
    passed++;
  } else {
    warn('.cc-sessions/ not created');
  }

  // Summary
  console.log('');
  if (failed === 0) {
    console.log(`  ${color.green}${sym.check}${color.reset} All ${passed} checks passed`);
  } else {
    console.log(`  ${color.red}${sym.cross}${color.reset} ${failed} checks failed, ${passed} passed`);
  }

  return failed === 0;
}

module.exports = { verify };
