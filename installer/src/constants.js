'use strict';

const path = require('path');
const os = require('os');

const VERSION = '2.4.0';
const PLUGIN_NAME = 'blitz';
const MARKETPLACE_NAME = 'blitz';
const PLUGIN_KEY = `${PLUGIN_NAME}@${MARKETPLACE_NAME}`;
const REPO_URL = 'https://github.com/lasswellt/blitz-cc.git';
const REPO_WEB = 'https://github.com/lasswellt/blitz-cc';

const CLAUDE_HOME = path.join(os.homedir(), '.claude');
const CLAUDE_SETTINGS = path.join(CLAUDE_HOME, 'settings.json');
const INSTALLED_PLUGINS = path.join(CLAUDE_HOME, 'plugins', 'installed_plugins.json');
const KNOWN_MARKETPLACES = path.join(CLAUDE_HOME, 'plugins', 'known_marketplaces.json');

const AGENT_NAMES = [
  'architect.md',
  'backend-dev.md',
  'doc-writer.md',
  'frontend-dev.md',
  'reviewer.md',
  'test-writer.md',
];

const BASE_PERMISSIONS = {
  allow: [
    'Bash(npx *)',
    'Bash(node *)',
    'Bash(git add *)',
    'Bash(git commit *)',
    'Bash(git status *)',
    'Bash(git diff *)',
    'Bash(git log *)',
    'Bash(git branch *)',
    'Bash(git push origin HEAD)',
    'Bash(git push origin HEAD:*)',
    'Bash(git push --set-upstream *)',
    'Bash(git push -u origin *)',
    'Bash(git pull *)',
    'Bash(gh issue *)',
    'Bash(gh label *)',
    'Bash(gh pr *)',
    'Bash(gh api *)',
    'Bash(python3 *)',
    'Bash(mkdir *)',
    'Bash(ls *)',
    'Bash(jq *)',
    'Bash(tree *)',
    'Bash(find *)',
    'Bash(wc *)',
    'Bash(curl http://localhost:*)',
    'WebSearch',
  ],
  deny: [
    'Bash(rm -rf *)',
    // History-rewriting push variants. Hook block-destructive-git.sh is the
    // second layer; this is the first (prompt-on-attempt).
    'Bash(git push --force *)',
    'Bash(git push --force-with-lease *)',
    'Bash(git push -f *)',
  ],
};

const STACK_PERMISSIONS = {
  pnpm:      { allow: ['Bash(pnpm *)'],      deny: ['Bash(pnpm publish *)'] },
  yarn:      { allow: ['Bash(yarn *)'],       deny: ['Bash(yarn publish *)'] },
  npm:       { allow: ['Bash(npm *)'],        deny: ['Bash(npm publish *)'] },
  firebase:  { allow: ['Bash(firebase *)', 'WebFetch(domain:firebase.google.com)', 'WebFetch(domain:cloud.google.com)'], deny: [] },
  vue:       { allow: ['WebFetch(domain:vuejs.org)'],       deny: [] },
  vuefire:   { allow: ['WebFetch(domain:vuefire.vuejs.org)'], deny: [] },
  quasar:    { allow: ['WebFetch(domain:quasar.dev)'],      deny: [] },
  vuetify:   { allow: ['WebFetch(domain:vuetifyjs.com)'],   deny: [] },
  tailwind:  { allow: ['WebFetch(domain:tailwindcss.com)'], deny: [] },
};

module.exports = {
  VERSION,
  PLUGIN_NAME,
  MARKETPLACE_NAME,
  PLUGIN_KEY,
  REPO_URL,
  REPO_WEB,
  CLAUDE_HOME,
  CLAUDE_SETTINGS,
  INSTALLED_PLUGINS,
  KNOWN_MARKETPLACES,
  AGENT_NAMES,
  BASE_PERMISSIONS,
  STACK_PERMISSIONS,
};
