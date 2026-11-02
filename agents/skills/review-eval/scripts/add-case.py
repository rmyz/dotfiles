import json
import subprocess
import sys
from pathlib import Path

DATA = Path.home() / 'Code/ai-generated/files/review-eval'
KIBANA = str(Path.home() / 'Code/kibana')


def run(*args):
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout


def gh_list(path):
    return [json.loads(line) for line in run('gh', 'api', '--paginate', path, '--jq', '.[] | tojson').splitlines()]


def git(*args):
    return run('git', '-C', KIBANA, *args)


pr, rev, picks = int(sys.argv[1]), sys.argv[2], [arg.split('=', 1) for arg in sys.argv[3:]]

meta = json.loads(run('gh', 'api', f'repos/elastic/kibana/pulls/{pr}'))
git('fetch', '--quiet', 'upstream', rev, meta['base']['sha'])
base = git('merge-base', rev, meta['base']['sha']).strip()
files = set(git('diff', '--name-only', base, rev).split())
numstat = (line.split('\t') for line in git('diff', '--numstat', base, rev).splitlines())
lines = sum(int(added) + int(deleted) for added, deleted, _ in numstat if added != '-')

inline = {c['id']: c for c in gh_list(f'repos/elastic/kibana/pulls/{pr}/comments')}
reviews = {r['id']: r for r in gh_list(f'repos/elastic/kibana/pulls/{pr}/reviews')}

expected = []
for k, (cid, theme) in enumerate(picks, 1):
    cid = int(cid)
    if cid in inline:
        c = inline[cid]
        assert c['original_commit_id'] == rev, f'{cid} was made on {c["original_commit_id"]}'
        assert c['path'] in files, f'{cid} is on {c["path"]}, outside the diff'
        file, line, user, body = c['path'], c.get('original_line'), c['user']['login'], c['body']
    else:
        r = reviews[cid]
        assert r['commit_id'] == rev, f'{cid} was made on {r["commit_id"]}'
        file, line, user, body = None, None, r['user']['login'], r['body']
    expected.append({'id': f'{pr}-{k}', 'file': file, 'line': line, 'reviewer': user, 'theme': theme, 'comment': body.strip()[:600]})

cases_path = DATA / 'cases.json'
cases = [c for c in json.loads(cases_path.read_text()) if c['pr'] != pr]
split = 'holdout' if pr % 3 == 0 else 'dev'
cases.append({'pr': pr, 'title': meta['title'], 'split': split, 'base_sha': base, 'reviewed_sha': rev, 'diff_lines': lines, 'expected': expected})
cases_path.write_text(json.dumps(sorted(cases, key=lambda c: c['pr']), indent=2) + '\n')

with open(DATA / 'harvested.txt', 'a') as harvested:
    harvested.write(f'{pr}\n')

print(f'{pr}\t{split}\t{lines} lines\t{len(expected)} expected')
