#!/usr/bin/env python3
"""Install every live official package anonymously, with Git unavailable."""
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
BASE = 'https://kennel.kujolang.ai'


def verify(package):
    with tempfile.TemporaryDirectory(prefix='kennel-public-install-') as temporary:
        root = Path(temporary)
        home = root/'home'
        home.mkdir()
        project = root/'project'
        project.mkdir()
        binaries = root/'bin'
        binaries.mkdir()
        git = binaries/'git'
        git.write_text('#!/bin/sh\necho "Unexpected Git access during registry install" >&2\nexit 97\n')
        git.chmod(0o755)
        env = {**os.environ, 'HOME': str(home), 'PATH': str(binaries)+os.pathsep+os.environ['PATH']}
        kujo = os.environ.get('KUJO_BIN', 'kujo')
        def run(*args):
            started = time.monotonic()
            result = subprocess.run([kujo, 'run', str(ROOT/'kennel.kujo'), '--interpreter', '--', *args, '--project-dir', str(project)], env=env, text=True, capture_output=True, timeout=180)
            if result.returncode:
                raise RuntimeError(result.stdout+result.stderr)
            return round(time.monotonic()-started, 3)
        name = package['name']
        run('init', '--name', 'public-install-acceptance')
        fresh = run('add', name)
        assert (project/'kennel_packages'/name/'kennel.toml').is_file()
        lock = (project/'kennel.lock').read_text()
        assert 'registry-statement-verified' in lock and package['latest'] in lock
        shutil.rmtree(project/'kennel_packages')
        cached = run('install')
        assert (project/'kennel_packages'/name/'kennel.toml').is_file()
        return {'package': name, 'version': package['latest'], 'fresh_seconds': fresh, 'cached_seconds': cached, 'git_disabled': True, 'status': 'passed'}


def main():
    request = urllib.request.Request(BASE+'/api/v1/index.json', headers={'User-Agent': 'Kennel/registry-v1'})
    with urllib.request.urlopen(request, timeout=30) as response:
        packages = json.load(response)['packages']
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = {pool.submit(verify, p): p['name'] for p in packages}
        for future in concurrent.futures.as_completed(futures):
            try:
                result = future.result()
            except Exception as error:
                result = {'package': futures[future], 'status': 'failed', 'error': str(error)}
            results.append(result)
            print(json.dumps(result), flush=True)
    passed = all(r['status']=='passed' for r in results)
    print(json.dumps({'total': len(results), 'passed': sum(r['status']=='passed' for r in results)}))
    raise SystemExit(0 if passed else 1)

if __name__ == '__main__':
    main()
