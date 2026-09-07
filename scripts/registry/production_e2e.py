#!/usr/bin/env python3
"""Explicit production acceptance check; isolated projects/cache, real HTTPS only."""
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


def main():
    kujo = os.environ.get('KUJO_BIN', 'kujo')
    results = {}
    with tempfile.TemporaryDirectory(prefix='kennel-production-e2e-') as temporary:
        root = Path(temporary)
        home = root / 'home'
        home.mkdir()
        env = {**os.environ, 'HOME': str(home)}
        def run(project, *args):
            start = time.monotonic()
            subprocess.run([kujo, 'run', str(ROOT/'kennel.kujo'), '--interpreter', '--', *args, '--project-dir', str(project)], env=env, check=True, timeout=120)
            return round(time.monotonic()-start, 3)
        for package in ('changebucket', 'kennel'):
            request = urllib.request.Request(BASE+'/api/v1/packages/'+package+'.json')
            with urllib.request.urlopen(request, timeout=30) as response:
                metadata = json.load(response)
            version = metadata['latest']
            project = root / package
            project.mkdir()
            run(project, 'init', '--name', 'registry-acceptance')
            results[package+'_uncached_seconds'] = run(project, 'add', package)
            lock = (project/'kennel.lock').read_text()
            assert 'registry-statement-verified' in lock and BASE in lock
            assert version in lock
            shutil.rmtree(project/'kennel_packages')
            results[package+'_cached_seconds'] = run(project, 'install')
            assert (project/'kennel_packages'/package/'kennel.toml').is_file()
            exact = root / (package+'-exact')
            exact.mkdir()
            run(exact, 'init', '--name', 'registry-exact-acceptance')
            results[package+'_exact_seconds'] = run(exact, 'add', package+'@'+version)
            clean = root / (package+'-clean')
            clean.mkdir()
            shutil.rmtree(home/'.kennel/cache')
            run(clean, 'init', '--name', 'registry-clean-acceptance')
            results[package+'_clean_seconds'] = run(clean, 'add', package)
        print(json.dumps(results, sort_keys=True, indent=2))

if __name__ == '__main__':
    main()
