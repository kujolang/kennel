#!/usr/bin/env python3
"""Opt-in live-registry global-command check; never changes the user's PATH/home."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    kujo = shutil.which(os.environ.get('KUJO_BIN', 'kujo'))
    if not kujo:
        raise SystemExit('Set KUJO_BIN to a runtime with --isolated-imports')
    kujo = str(Path(kujo).resolve())
    expected = re.search(r'^version = "([^"]+)"', (ROOT/'kennel.toml').read_text(), re.M).group(1)
    results = {}
    with tempfile.TemporaryDirectory(prefix='kennel-global-production-') as temporary:
        home = Path(temporary).resolve()
        base = home/'custom-kennel'
        (home/'src').mkdir()
        (home/'src/cli.kujo').write_text('print("CALLER MODULE MUST NOT EXECUTE")\nexit(93)\n')
        env = {**os.environ, 'HOME': str(home), 'KENNEL_HOME': str(base),
               'KUJO_BIN': kujo, 'PYTHON_BIN': sys.executable}

        def run(*args, code=0):
            result = subprocess.run(list(map(str, args)), env=env, cwd=home,
                                    capture_output=True, text=True, timeout=180)
            assert result.returncode == code, (args, result.returncode, result.stdout, result.stderr)
            return result.stdout if code == 0 else result.stdout + result.stderr

        run(sys.executable, ROOT/'scripts/install.py', '--source', ROOT, '--no-modify-path')
        launcher = base/'bin/kennel'
        assert run(launcher, '--version').strip() == 'Kennel '+expected
        for name in ('shipcheck', 'spec', 'changebucket', 'runledger'):
            start = time.monotonic()
            # Explicit shadowing applies only to disposable shims, never existing executables.
            run(launcher, 'tool', 'install', name, '--allow-shadow')
            assert run(base/'bin'/name, '--help').strip(), name
            state = json.loads((base/'tools.json').read_text())
            results[name] = {'version': state['packages'][name]['version'],
                             'install_and_help_seconds': round(time.monotonic()-start, 3)}
        assert (base/'cache/sha256').is_dir()
        assert not (home/'.kennel/cache').exists()
        run(launcher, 'tool', 'install', 'shipcheck@1.0.0', '--allow-shadow')
        run(launcher, 'tool', 'update', 'shipcheck', '--allow-shadow')
        state = json.loads((base/'tools.json').read_text())
        assert state['packages']['shipcheck']['spec'] == 'shipcheck@1.0.0'
        before = (base/'client').resolve()
        rejected = run(launcher, 'self', 'update', '--version', '1.0.1', code=1)
        assert 'historical' in rejected.lower() or 'predates' in rejected.lower(), rejected
        assert (base/'client').resolve() == before
        run(base/'bin/shipcheck', '--help')
    print(json.dumps({'passed': True, 'review_client_version': expected, 'tools': results,
                      'exact_pin_update': True, 'failed_client_update_preserves_install': True},
                     sort_keys=True, indent=2))


if __name__ == '__main__':
    main()
