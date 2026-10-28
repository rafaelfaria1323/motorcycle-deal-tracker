#!/usr/bin/env python3
"""Mutation testing (like Stryker) with the `mutation_test` Dart tool.

Each target file (listed in <package>/mutation_targets.txt) gets small
changes, one at a time (`<` to `<=`, `&&` to `||`, a constant changed...),
and its tests run after each one. A change no test notices is a
"surviving mutant": a gap in the tests. No AI involved.

  plan [--changed-from REF] [--shards N]
      Prints the GitHub Actions matrix (JSON): every target split in N jobs
      per package, or with --changed-from only the targets whose file or
      test changed since REF.
  run <package> <out_dir> <file>...
      Mutates the files (in place: the tool restores each file after its
      run, so don't stop it halfway) and writes one report per file.
  summary [--floor N] <dir>...
      Prints a Markdown summary of the reports found in the folders; with
      --floor, fails (exit 1) when the score is below N %.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

PACKAGES = ('collector', 'app')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def targets(package):
    path = os.path.join(ROOT, package, 'mutation_targets.txt')
    with open(path, encoding='utf-8') as f:
        return [
            line.strip()
            for line in f
            if line.strip() and not line.startswith('#')
        ]


def own_test(target):
    """test/<name>_test.dart of a target file."""
    name = os.path.basename(target)[: -len('.dart')]
    return f'test/{name}_test.dart'


def test_command(package, target):
    if package == 'app':
        return f'flutter test --no-pub {own_test(target)}'
    return 'dart test -r failures-only'


def plan(args):
    shards = 4
    changed_from = None
    while args:
        flag = args.pop(0)
        if flag == '--shards':
            shards = int(args.pop(0))
        elif flag == '--changed-from':
            changed_from = args.pop(0)
        else:
            sys.exit(f'Unknown option {flag}')

    changed = None
    if changed_from:
        out = subprocess.run(
            ['git', 'diff', '--name-only', changed_from, 'HEAD'],
            cwd=ROOT, check=True, capture_output=True, text=True,
        ).stdout
        changed = set(out.split())

    jobs = []
    for package in PACKAGES:
        files = targets(package)
        if changed is not None:
            files = [
                f for f in files
                if f'{package}/{f}' in changed
                or (package == 'app' and f'app/{own_test(f)}' in changed)
            ]
            parts = [files] if files else []
        else:
            # Round robin over a list sorted biggest first: similar shares.
            parts = [files[i::shards] for i in range(shards) if files[i::shards]]
        for i, part in enumerate(parts):
            jobs.append({
                'name': f'{package} {i + 1}/{len(parts)}',
                'package': package,
                'files': ' '.join(part),
            })
    print(json.dumps({'include': jobs}))


def run(args):
    package, out_dir, files = args[0], os.path.abspath(args[1]), args[2:]
    cwd = os.path.join(ROOT, package)
    for target in files:
        slug = re.sub(r'[^A-Za-z0-9]+', '-', f'{package}/{target}').strip('-')
        config = f'''<?xml version="1.0" encoding="UTF-8"?>
<mutations version="1.2">
  <files><file>{target}</file></files>
  <commands>
    <command group="test" expected-return="0" working-directory="." timeout="300">{test_command(package, target)}</command>
  </commands>
</mutations>
'''
        with tempfile.NamedTemporaryFile(
            'w', suffix='.xml', delete=False, encoding='utf-8'
        ) as f:
            f.write(config)
        print(f'== {package}/{target}', flush=True)
        # Exit code ignored: the quality gate is ours to judge (summary).
        subprocess.run(
            ['mutation_test', '-f', 'all', '-o', os.path.join(out_dir, slug),
             f.name],
            cwd=cwd,
        )
        with open(os.path.join(out_dir, slug, 'target.txt'), 'w',
                  encoding='utf-8') as t:
            t.write(f'{package}/{target}\n')
        os.unlink(f.name)


def _table_value(markdown, key):
    match = re.search(rf'^\|\s*{key}\s*\|\s*(\d+)', markdown, re.M)
    return int(match.group(1)) if match else 0


def summary(args):
    floor = None
    if args[:1] == ['--floor']:
        floor = float(args[1])
        args = args[2:]
    rows = []
    survivors = []
    for base in args:
        for dirpath, _, names in sorted(os.walk(base)):
            if 'target.txt' not in names:
                continue
            with open(os.path.join(dirpath, 'target.txt'), encoding='utf-8') as f:
                target = f.read().strip()
            md = os.path.join(dirpath, 'mutation-test-report.md')
            xml = os.path.join(dirpath, 'mutation-test-report.xml')
            if not os.path.exists(md) or not os.path.exists(xml):
                rows.append((target, 0, 0, 0, 'no report'))
                continue
            with open(md, encoding='utf-8') as f:
                text = f.read()
            total = _table_value(text, 'Mutations')
            undetected = _table_value(text, 'Undetected')
            timeouts = _table_value(text, 'Timeouts')
            rows.append((target, total, undetected, timeouts, ''))
            for mutation in ET.parse(xml).getroot().iter('mutation'):
                survivors.append((
                    target,
                    mutation.get('line'),
                    (mutation.findtext('original') or '').strip(),
                    (mutation.findtext('modified') or '').strip(),
                ))

    total = sum(r[1] for r in rows)
    undetected = sum(r[2] for r in rows)
    killed = total - undetected
    score = 100 * killed / total if total else 100
    out = [
        '# Mutation testing',
        '',
        f'**Score: {score:.0f} %** ({killed} of {total} mutations caught by '
        f'a test; {undetected} survived).',
        '',
        '| File | Mutations | Survived | Score |',
        '|---|---:|---:|---:|',
    ]
    for target, n, left, timeouts, note in sorted(rows, key=lambda r: -r[2]):
        file_score = f'{100 * (n - left) / n:.0f} %' if n else '-'
        extra = f' ({timeouts} timeouts)' if timeouts else ''
        out.append(f'| `{target}` | {n} | {left}{extra} | {note or file_score} |')
    if survivors:
        out += [
            '',
            '## Surviving mutants',
            '',
            'Each line: a change to the code that no test noticed. Add a test '
            'that fails with it, unless the change makes no real difference '
            '(an "equivalent" mutant).',
            '',
        ]
        for target, line, original, modified in survivors:
            out.append(f'- `{target}:{line}`: `{original}` → `{modified}`')
    print('\n'.join(out))
    if floor is not None and score < floor:
        sys.exit(f'Mutation score {score:.1f} % is below the floor of '
                 f'{floor:g} %.')


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ('plan', 'run', 'summary'):
        sys.exit(__doc__)
    {'plan': plan, 'run': run, 'summary': summary}[sys.argv[1]](sys.argv[2:])


if __name__ == '__main__':
    main()
