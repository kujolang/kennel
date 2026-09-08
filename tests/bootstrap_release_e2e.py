#!/usr/bin/env python3
"""Exercise the release bootstrap with a local fixture release, never publish it."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from unittest.mock import patch

ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'scripts/registry'))
from build_package import build, tomllib
spec=importlib.util.spec_from_file_location('bootstrap',ROOT/'scripts/install.py')
bootstrap=importlib.util.module_from_spec(spec);spec.loader.exec_module(bootstrap)
version=tomllib.loads((ROOT/'kennel.toml').read_text())['package']['version']
with tempfile.TemporaryDirectory(prefix='kennel-bootstrap-fixture-') as temp:
    folder=Path(temp).resolve();repo=folder/'fixture';user=folder/'user';user.mkdir()
    subprocess.run(['git','clone','-q','--shared',str(ROOT),str(repo)],check=True)
    commit=subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()
    subprocess.run(['git','-C',str(repo),'tag','-f','v'+version,commit],check=True,stdout=subprocess.DEVNULL)
    release={'repository':'kujolang/kennel','repository_id':1264528549,'id':1,'draft':False,
             'prerelease':False,'tag_name':'v'+version,'published_at':'2026-09-08T00:00:00Z'}
    policy={'schema_version':1,'packages':{'kennel':{'repository':'kujolang/kennel','repository_id':1264528549,'official':True,'enabled':True}}}
    workflow={'run':'https://github.com/kujolang/kennel-registry/actions/runs/1',
              'ref':'kujolang/kennel/.github/workflows/publish-kennel-package.yml@'+commit,'sha':commit,'published_at':'2026-09-08T00:00:00Z'}
    manifest, artifacts=build(repo,commit,release,policy,workflow,bootstrap.REGISTRY)
    _, repeated=build(repo,commit,release,policy,workflow,bootstrap.REGISTRY)
    assert artifacts==repeated,'Candidate packaging must be deterministic'
    responses={bootstrap.REGISTRY+'/api/v1/packages/kennel/'+version+'.json':json.dumps(manifest).encode(),
               manifest['archive_url']:artifacts['package.tar.gz'],manifest['provenance_url']:artifacts['provenance.json']}
    def fetch(url,limit):
        data=responses[url];assert len(data)<=limit;return data
    with patch.dict(os.environ,{'HOME':str(user),'KENNEL_HOME':str(user/'.kennel')}),patch.object(bootstrap,'fetch',side_effect=fetch):
        bootstrap.main(['--version',version,'--no-modify-path'])
        launcher=user/'.kennel/bin/kennel'
        text=subprocess.check_output([str(launcher),'--version'],text=True)
        assert text.strip()=='Kennel '+version,text
        subprocess.run([str(launcher),'tool','--help'],check=True,stdout=subprocess.DEVNULL)
        old=(user/'.kennel/client').resolve()
        responses[manifest['archive_url']]=b'corrupt'
        try:bootstrap.main(['--version',version,'--no-modify-path'])
        except ValueError:pass
        else:raise AssertionError('Corrupt release bootstrap must fail')
        assert (user/'.kennel/client').resolve()==old
    print(json.dumps({'fixture_only':True,'version':version,'archive_bytes':manifest['archive_size'],
                      'file_count':manifest['file_count'],'sha256':manifest['archive_sha256']}))
print('PASS: deterministic candidate archive, release-path bootstrap, installed version/global CLI, corrupt-update rollback; no public release created')
