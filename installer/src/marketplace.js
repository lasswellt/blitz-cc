'use strict';

const { CLAUDE_SETTINGS, MARKETPLACE_NAME, REPO_URL } = require('./constants');
const { read, write, setNestedValue, getNestedValue } = require('./settings');
const { success, info } = require('./ui');

function registerMarketplace(opts = {}) {
  const settings = read(CLAUDE_SETTINGS);
  const key = `extraKnownMarketplaces.${MARKETPLACE_NAME}`;
  const existing = getNestedValue(settings, key);

  if (existing) {
    success('Marketplace already registered (skipped)');
    return false;
  }

  // Auto-update opt-in. Defaults to disabled because enabling authorizes Claude
  // Code to pull plugin updates (including hook scripts that run as the user's
  // OS process) from the upstream repository on every session start, with no
  // further prompt. If upstream is compromised, every install silently pulls
  // attacker code. Caller must explicitly opt in.
  // opts.autoUpdate: undefined/false = off (default), true = on.
  // opts.yes: skip the prompt (CI / --yes flag), defaults to off.
  const autoUpdate = opts.autoUpdate === true;
  const entry = {
    source: { source: 'git', url: REPO_URL },
    autoUpdate,
  };

  setNestedValue(settings, key, entry);

  if (opts.dryRun) {
    info(`Would register marketplace "${MARKETPLACE_NAME}" in ${CLAUDE_SETTINGS}`);
    return true;
  }

  write(CLAUDE_SETTINGS, settings);
  success(`Marketplace "${MARKETPLACE_NAME}" registered`);
  return true;
}

function unregisterMarketplace(opts = {}) {
  const settings = read(CLAUDE_SETTINGS);
  const key = `extraKnownMarketplaces.${MARKETPLACE_NAME}`;
  const existing = getNestedValue(settings, key);

  if (!existing) {
    info('Marketplace not registered (nothing to remove)');
    return false;
  }

  if (opts.dryRun) {
    info(`Would remove marketplace "${MARKETPLACE_NAME}" from ${CLAUDE_SETTINGS}`);
    return true;
  }

  const { removeNestedKey } = require('./settings');
  removeNestedKey(settings, key);
  write(CLAUDE_SETTINGS, settings);
  success('Marketplace removed');
  return true;
}

module.exports = { registerMarketplace, unregisterMarketplace };
