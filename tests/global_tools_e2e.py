#!/usr/bin/env python3
"""Offline installer and global CLI lifecycle, using the real Kujo client."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parent.parent
kujo=shutil.which(os.environ.get('KUJO_BIN','kujo'))
if not kujo:raise SystemExit('KUJO_BIN or kujo is required')
with tempfile.TemporaryDirectory(prefix='kennel-global-e2e-') as temporary:
    folder=Path(temporary).resolve();user=folder/'user home';user.mkdir();base=user/'.kennel'
    env={**os.environ,'HOME':str(user),'KUJO_BIN':kujo,'KENNEL_HOME':str(base)}
    def run(*args,expected=0,cwd=folder):
        result=subprocess.run(list(map(str,args)),env=env,cwd=cwd,text=True,capture_output=True)
        assert result.returncode==expected,(args,result.returncode,result.stdout,result.stderr)
        return result.stdout
    setup=[sys.executable,ROOT/'scripts/install.py','--source',ROOT]
    run(*setup)
    profiles=(user/'.zshrc').read_bytes()
    run(*setup)
    assert profiles==(user/'.zshrc').read_bytes()
    kennel=base/'bin/kennel'
    env['PATH']=str(base/'bin')+os.pathsep+env['PATH']
    run(kennel,'help')
    assert 'Kennel' in run(kennel)
    assert run(kennel,'--version').strip() == 'Kennel 1.1.0'
    source=folder/'global-demo';source.mkdir()
    def manifest(version):
        (source/'kennel.toml').write_text(f'[package]\nname="global-demo"\nversion="{version}"\n[kujo]\nentry="main.kujo"\n[bin]\nglobal-demo="main.kujo"\nglobal-exit="exit.kujo"\n')
    manifest('1.0.0')
    (source/'helper.kujo').write_text('export value := "installed module"\n')
    (folder/'helper.kujo').write_text('print("WORKSPACE MODULE MUST NOT EXECUTE")\nexport value := "workspace"\n')
    (source/'main.kujo').write_text('from helper import value\nassert(value == "installed module")\nprint(to_json({"cwd": os_getcwd(), "args": args()}))\n')
    (source/'exit.kujo').write_text('exit(7)\n')
    spec='file:'+str(source)
    run(kennel,'tool','install',spec)
    result=json.loads(run(base/'bin/global-demo','space argument','--flag','"quote"'))
    assert result=={'cwd':str(folder),'args':['space argument','--flag','"quote"']},result
    assert json.loads(run(base/'bin/global-demo'))['args']==[]
    assert json.loads(run(base/'bin/global-demo','a\x1fb'))['args']==['a\x1fb']
    run(base/'bin/global-exit',expected=7)
    assert 'global-demo 1.0.0' in run(kennel,'tool','list')
    manifest('1.1.0');run(kennel,'tool','update','global-demo')
    assert 'global-demo 1.1.0' in run(kennel,'tool','list')
    before=(base/'tools.json').read_bytes()
    (source/'kennel.toml').write_text('[package]\nname="global-demo"\nversion="1.2.0"\n[bin]\nglobal-demo="../escape.kujo"\n')
    run(kennel,'tool','update','global-demo',expected=1)
    assert before==(base/'tools.json').read_bytes()
    run(base/'bin/global-demo','still works')
    # Installer collision cannot overwrite user-owned executables.
    other=folder/'other';(other/'bin').mkdir(parents=True);(other/'bin/kennel').write_text('user command')
    run(*setup,'--home',other,expected=1)
    assert (other/'bin/kennel').read_text()=='user command'
    run(kennel,'tool','remove','global-demo')
    assert not (base/'bin/global-demo').exists() and not (base/'bin/global-exit').exists()
    assert run(kennel,'tool','list')==''
    assert not (folder/'kennel.toml').exists()
print('PASS: offline installer, PATH idempotency, global multi-command install, caller cwd/argv/exit, update, failed-update rollback, collision protection and removal')
