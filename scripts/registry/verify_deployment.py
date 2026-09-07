#!/usr/bin/env python3
"""Wait for the atomic Pages deployment and check exact immutable bytes."""
import hashlib
import json
from pathlib import Path
import sys
import time
import urllib.request
root=Path(sys.argv[1])
expected=(root/'api/v1/index.json').read_bytes()
for attempt in range(40):
    try:
        with urllib.request.urlopen('https://kennel.kujolang.ai/api/v1/index.json',timeout=15) as r:
            if r.read(1048577) != expected:
                raise ValueError('Deployment has not caught up')
        for manifest in root.glob('packages/*/*/manifest.json'):
            m=json.loads(manifest.read_bytes())
            with urllib.request.urlopen(m['archive_url'],timeout=30) as r:
                blob=r.read(8388609)
            if hashlib.sha256(blob).hexdigest()!=m['archive_sha256']:
                raise ValueError('Deployed artifact digest mismatch')
        print('Production index and all immutable archive digests verified')
        break
    except Exception as error:
        if attempt==39:
            raise
        print(f'Waiting for Pages: {error}',flush=True)
        time.sleep(15)
