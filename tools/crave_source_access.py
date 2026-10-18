#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Inspect exact public release refs and test Git transfers on a queued node."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import xml.etree.ElementTree as ET


def gitcode_projects(manifest):
    root = ET.parse(manifest).getroot()
    remotes = {r.attrib['name']: r.attrib['fetch'] for r in root.findall('remote')}
    default = root.find('default')
    defaults = default.attrib if default is not None else {}
    projects = []
    for p in root.findall('project'):
        remote = p.get('remote', defaults.get('remote'))
        fetch = remotes.get(remote, '')
        if fetch.rstrip('/') != 'https://gitcode.com/openharmony':
            continue
        revision = p.get('revision', defaults.get('revision', ''))
        if not revision or revision.startswith('refs/tags/'):
            raise ValueError('Expected a release branch for ' + p.attrib['name'])
        projects.append({'name': p.attrib['name'],
                         'path': p.get('path', p.attrib['name']),
                         'ref': revision if revision.startswith('refs/') else 'refs/heads/' + revision})
    if not projects:
        raise ValueError('No GitCode projects found; inspect changed manifest before proceeding')
    return projects


def release_tip(url, ref):
    try:
        result = subprocess.run(['git', 'ls-remote', '--exit-code', url, ref],
                                text=True, capture_output=True, timeout=60)
    except subprocess.TimeoutExpired:
        return None, 'timeout after 60 seconds'
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[1] == ref and result.returncode == 0:
            return fields[0], None
    return None, result.stderr.strip()[-800:] or 'exact release ref not advertised'


def fetch_project(path, attempts=3):
    # Fetch real Git objects into repo's existing object store. Ref listing alone
    # does not establish that pack transfers work. No source deletion or reset.
    for attempt in range(1, attempts + 1):
        print(f'GITCODE_FETCH path={path} attempt={attempt}/{attempts}', flush=True)
        try:
            result = subprocess.run(['repo', 'sync', '-c', '--network-only',
                                     '--fail-fast', '-j1', path], timeout=1800)
            if result.returncode == 0:
                return True
        except subprocess.TimeoutExpired:
            print('Fetch exceeded 30-minute per-attempt limit', flush=True)
        if attempt < attempts:
            time.sleep(15 * attempt)
    return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--fetch-all', action='store_true')
    args = parser.parse_args()
    if os.environ.get('CRAVE_BUILD_NODE') != '1':
        parser.error('Run only through crave run on an allocated build node')
    projects = gitcode_projects(args.manifest)
    rows = []
    for project in projects:
        name, ref = project['name'], project['ref']
        original = 'https://gitcode.com/openharmony/' + name + '.git'
        source_sha, error = release_tip(original, ref)
        row = {**project, 'source_sha': source_sha, 'source_error': error, 'mirrors': []}
        for organization in ('eclipse-oniro-mirrors', 'openharmony'):
            url = f'https://github.com/{organization}/{name}.git'
            sha, mirror_error = release_tip(url, ref)
            row['mirrors'].append({'url': url, 'sha': sha, 'error': mirror_error,
                                   'matches_source_tip': bool(source_sha and sha == source_sha)})
        rows.append(row)
        print('SOURCE_ACCESS ' + json.dumps(row, sort_keys=True), flush=True)
    Path('source-access-report.json').write_text(json.dumps(rows, indent=2) + '\n')
    if args.fetch_all:
        selected = projects
    else:
        selected = [p for p in projects if p['name'] == 'developtools_profiler']
        if not selected:
            raise ValueError('Expected profiler fetch probe is missing')
    # A mirror's matching ref is evidence only. Never silently rewrite manifest
    # remotes: review the report and verify actual object/LFS availability first.
    failed = []
    for project in selected:
        if not fetch_project(project['path']):
            failed.append(project['path'])
            break
    print('SOURCE_FETCH_FAILURES ' + json.dumps(failed), flush=True)
    return 1 if failed or any(not row['source_sha'] for row in rows) else 0


if __name__ == '__main__':
    sys.exit(main())
