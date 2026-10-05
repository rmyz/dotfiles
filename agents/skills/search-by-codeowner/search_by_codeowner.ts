/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the "Elastic License
 * 2.0", the "GNU Affero General Public License v3.0 only", and the "Server Side
 * Public License v 1"; you may not use this file except in compliance with, at
 * your election, the "Elastic License 2.0", the "GNU Affero General Public
 * License v3.0 only", or the "Server Side Public License, v 1".
 */

import fs from 'fs';
import os from 'os';
import path from 'path';
import { execFile, execFileSync } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

// Hardcoded root: this skill only ever scans the local Kibana checkout.
const KIBANA_ROOT = path.join(os.homedir(), 'Code', 'kibana');

interface CodeOwnerRule {
  pattern: string;
  owners: string[];
}

interface SearchResult {
  searchTerm: string;
  team: string;
  totalScannedFiles: number;
  totalMatchingFiles: number;
  matchingFiles: string[];
  analysisTimeMs: number;
}

function loadCodeOwners(): CodeOwnerRule[] {
  const codeownersPath = path.join(KIBANA_ROOT, '.github', 'CODEOWNERS');
  const rules: CodeOwnerRule[] = [];

  try {
    const content = fs.readFileSync(codeownersPath, 'utf8');
    const lines = content.split('\n');

    for (const line of lines) {
      const trimmed = line.trim();

      // Skip empty lines and comments
      if (!trimmed || trimmed.startsWith('#')) {
        continue;
      }

      // Parse line: pattern @team1 @team2 ...
      const parts = trimmed.split(/\s+/);
      if (parts.length < 2) {
        continue;
      }

      const pattern = parts[0];
      const owners = parts.slice(1).filter((part) => part.startsWith('@'));

      if (owners.length > 0) {
        rules.push({ pattern, owners });
      }
    }
  } catch (error) {
    // If CODEOWNERS doesn't exist or can't be read, return empty array
  }

  return rules;
}

function patternRegex(pattern: string): RegExp {
  const anchored = pattern.startsWith('/');
  const directory = pattern.endsWith('/');
  const body = pattern.replace(/^\//, '').replace(/\/$/, '');
  const regex = body
    .split(/(\*\*\/|\*\*)/g)
    .map((part) => {
      if (part === '**/') {
        return '(?:.*/)?';
      }
      if (part === '**') {
        return '.*';
      }
      return part
        .split(/(\*)/g)
        .map((segment) => (segment === '*' ? '[^/]*' : segment.replace(/[|\\{}()[\]^$+?.]/g, '\\$&')))
        .join('');
    })
    .join('');
  const prefix = anchored || body.includes('/') ? '^' : '^(?:.*/)?';
  const descendants = directory ? '/.+' : !body.includes('*') ? '(?:/.*)?' : '';
  return new RegExp(`${prefix}${regex}${descendants}$`);
}

function ownedFiles(team: string, rules: CodeOwnerRule[]): string[] {
  const normalizedTeam = team.toLowerCase();
  const compiledRules = rules.map((rule) => ({ ...rule, regex: patternRegex(rule.pattern) }));
  return execFileSync('git', ['-C', KIBANA_ROOT, 'ls-files'], {
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024,
  })
    .split('\n')
    .filter(Boolean)
    .filter((file) => !file.split('/').some((part) => ['node_modules', '.git', 'build', 'target'].includes(part)))
    .filter((file) => /\.(?:js|jsx|ts|tsx|json|md|yml|yaml)$/i.test(file))
    .filter((file) => {
      let owner: (typeof compiledRules)[number] | undefined;
      for (let index = compiledRules.length - 1; index >= 0; index--) {
        if (compiledRules[index].regex.test(file)) {
          owner = compiledRules[index];
          break;
        }
      }
      return owner?.owners.some((candidate) => candidate.toLowerCase() === normalizedTeam) ?? false;
    });
}

async function searchWithGrepInFiles(searchTerm: string, files: string[]): Promise<string[]> {
  if (files.length === 0) {
    return [];
  }

  const matches: string[] = [];
  for (let offset = 0; offset < files.length; offset += 50) {
    try {
      const args = ['-il', '-e', searchTerm, '--', ...files.slice(offset, offset + 50).map((file) => path.join(KIBANA_ROOT, file))];
      const { stdout } = await execFileAsync('grep', args, { maxBuffer: 50 * 1024 * 1024 });
      matches.push(...stdout.split('\n').filter(Boolean).map((file) => path.resolve(file)));
    } catch (error: any) {
      if (typeof error === 'object' && error !== null && 'code' in error && error.code === 1) {
        const stdout = 'stdout' in error && typeof error.stdout === 'string' ? error.stdout : '';
        matches.push(...stdout.split('\n').filter(Boolean).map((file: string) => path.resolve(file)));
        continue;
      }
      return [];
    }
  }
  return matches;
}

async function performSearch(searchTerm: string, team: string): Promise<SearchResult> {
  const startTime = Date.now();
  const codeOwnerRules = loadCodeOwners();

  // Normalize team name (ensure it starts with @)
  const normalizedTeam = team.startsWith('@') ? team : `@${team}`;

  // First, get all paths owned by the team from CODEOWNERS
  const files = ownedFiles(normalizedTeam, codeOwnerRules);

  // Then search only in those paths (much faster!)
  const matchingFiles = await searchWithGrepInFiles(searchTerm, files);

  const relativeFiles = matchingFiles.map((file) => path.relative(KIBANA_ROOT, file)).sort();

  const endTime = Date.now();

  return {
    searchTerm,
    team: normalizedTeam,
    totalScannedFiles: files.length,
    totalMatchingFiles: relativeFiles.length,
    matchingFiles: relativeFiles,
    analysisTimeMs: endTime - startTime,
  };
}

async function main() {
  const args = process.argv.slice(2);
  let searchTerm = '';
  let team = '';

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--search' && args[i + 1]) {
      searchTerm = args[i + 1];
      i++;
    } else if (args[i] === '--team' && args[i + 1]) {
      team = args[i + 1];
      i++;
    } else if (args[i] === '--help' || args[i] === '-h') {
      console.log('Usage: node -r @kbn/setup-node-env search_by_codeowner.ts --team <team> --search <term>');
      console.log('');
      console.log('Options:');
      console.log('  --team <team>      GitHub team (e.g., @elastic/kibana-core)');
      console.log('  --search <term>    Term to search for (case-insensitive)');
      process.exit(0);
    }
  }

  if (!searchTerm || !team) {
    console.error('Error: --team and --search are required');
    process.exit(1);
  }

  const result = await performSearch(searchTerm, team);
  console.log(JSON.stringify(result, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
