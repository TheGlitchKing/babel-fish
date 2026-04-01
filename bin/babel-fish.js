#!/usr/bin/env node
'use strict';

const { execSync, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const INSTALL_SH = path.join(__dirname, '..', '.claude', 'install.sh');
const args = process.argv.slice(2);
const command = args[0] || 'init';

const helpText = `
  babel-fish — gives Claude instant codebase context

  Usage:
    npx @theglitchking/babel-fish [command] [options]

  Commands:
    init [path]    Install babel-fish into a project (default: current dir)
    dry-run [path] Preview all changes without applying them
    regen          Force-regenerate the project map
    grade          Grade the current project map quality
    help           Show this help

  Examples:
    npx @theglitchking/babel-fish init
    npx @theglitchking/babel-fish init /path/to/project
    npx @theglitchking/babel-fish dry-run
    npx @theglitchking/babel-fish regen
`;

function requireBash() {
  const result = spawnSync('bash', ['--version'], { stdio: 'ignore' });
  if (result.status !== 0) {
    console.error('  ✗ bash is required but not found.');
    process.exit(1);
  }
}

function run(bashArgs, opts = {}) {
  requireBash();
  const result = spawnSync('bash', bashArgs, {
    stdio: 'inherit',
    ...opts,
  });
  if (result.status !== 0) process.exit(result.status);
}

switch (command) {
  case 'init':
  case '--auto': {
    const target = args[1] || process.cwd();
    console.log(`\n  babel-fish init → ${target}\n`);
    run([INSTALL_SH, target]);
    break;
  }

  case 'dry-run': {
    const target = args[1] || process.cwd();
    run([INSTALL_SH, '--dry-run', target]);
    break;
  }

  case 'regen': {
    const generatePy = path.join(process.cwd(), '.claude', 'project-map', 'generate.py');
    if (!fs.existsSync(generatePy)) {
      console.error('  ✗ .claude/project-map/generate.py not found. Run `babel-fish init` first.');
      process.exit(1);
    }
    run(['python3', generatePy, '--force'], { shell: false });
    break;
  }

  case 'grade': {
    const graderPy = path.join(process.cwd(), '.claude', 'project-map', 'grader.py');
    if (!fs.existsSync(graderPy)) {
      console.error('  ✗ .claude/project-map/grader.py not found. Run `babel-fish init` first.');
      process.exit(1);
    }
    spawnSync('python3', [graderPy], { stdio: 'inherit' });
    break;
  }

  case 'help':
  case '--help':
  case '-h':
    console.log(helpText);
    break;

  default:
    console.error(`  Unknown command: ${command}`);
    console.log(helpText);
    process.exit(1);
}
