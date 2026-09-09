"""Test-only bridge: independent Python archive fixtures exercise the native publisher."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
KUJO = os.environ.get('KUJO_BIN', 'kujo')
def canonical(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()
def digest(value):
    return hashlib.sha256(value).hexdigest()
def run(source):
    with tempfile.TemporaryDirectory() as temporary:
        script = Path(temporary)/'test.kujo'
        script.write_text(source)
        result = subprocess.run([KUJO, 'run', str(script), '--interpreter', '--isolated-imports'], env={**os.environ, 'KUJO_MODULE_PATH': str(ROOT)}, text=True, capture_output=True)
        if result.returncode:
            raise ValueError(result.stdout + result.stderr)
        return result.stdout

def build(repo, commit, release, policy, workflow, base):
    with tempfile.TemporaryDirectory() as temporary:
        folder=Path(temporary)
        for name, data in [('release',release),('policy',policy),('workflow',workflow)]:
            (folder/(name+'.json')).write_bytes(canonical(data))
        read=lambda name: 'parse_json(read_file('+json.dumps(str(folder/(name+'.json')))+'))'
        source='from src.registry_package import package_build\nmut built := package_build('+','.join([json.dumps(str(repo)),json.dumps(commit),read('release'),read('policy'),read('workflow'),json.dumps(base)])+')\n'
        source+='for name in keys(built["artifacts"]) { io_write_bytes('+json.dumps(str(folder))+' + "/" + name, built["artifacts"][name]) }\n'
        run(source)
        metadata=json.loads((folder/'manifest.json').read_bytes())
        return metadata,{name:(folder/name).read_bytes() for name in ['package.tar.gz','manifest.json','provenance.json','checksums.txt']}

def publish(root, metadata, artifacts):
    with tempfile.TemporaryDirectory() as temporary:
        folder=Path(temporary)
        (folder/'metadata.json').write_bytes(canonical(metadata))
        for name,data in artifacts.items(): (folder/name).write_bytes(data)
        source='from src.registry_package import package_publish\nmut artifacts := {}\n'
        for name in artifacts:
            source+='artifacts['+json.dumps(name)+'] = io_read_bytes('+json.dumps(str(folder/name))+', 8388608)\n'
        source+='print(to_json(package_publish('+json.dumps(str(root))+', {"metadata":parse_json(read_file('+json.dumps(str(folder/'metadata.json'))+')), "artifacts":artifacts})))\n'
        return json.loads(run(source))

def generate(root):
    return run('from src.registry_site import site_generate\nsite_generate('+json.dumps(str(ROOT))+','+json.dumps(str(root))+')\n')
