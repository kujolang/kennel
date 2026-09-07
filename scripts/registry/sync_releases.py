#!/usr/bin/env python3
"""Reconcile published GitHub Releases against the explicit official policy."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import tempfile
from build_package import build, publish, git, VERSION
from generate_registry import generate


def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', path]))


def sync(root, policy_path, only_package='', only_release=''):
    root=Path(root)
    policy=json.loads(Path(policy_path).read_bytes())
    changed=[]
    for name, entry in sorted(policy['packages'].items()):
        if not entry.get('enabled') or only_package and name != only_package:
            continue
        repository=entry['repository']
        current=api('repos/'+repository)
        if current['id'] != entry['repository_id'] or current['owner']['login'] != 'kujolang' or current['private']:
            raise ValueError('Official repository identity/visibility changed')
        releases=api(f'repos/{repository}/releases?per_page=100')
        for release in sorted(releases,key=lambda r:r['id']):
            if release['draft'] or only_release and str(release['id']) != only_release:
                continue
            version=release['tag_name'].removeprefix('v')
            if not VERSION.fullmatch(version):
                raise ValueError('Published release has invalid SemVer tag')
            target=root/'packages'/name/version
            if target.exists():
                # Existing immutable versions are checked by generate(); never rebuilt on a timer.
                continue
            with tempfile.TemporaryDirectory(prefix='kennel-release-') as checkout:
                subprocess.run(['git','init','-q',checkout],check=True)
                subprocess.run(['git','-C',checkout,'fetch','--depth=1',f'https://github.com/{repository}.git','refs/tags/'+release['tag_name']+':refs/tags/'+release['tag_name']],check=True)
                commit=git(checkout,'rev-parse','refs/tags/'+release['tag_name']+'^{commit}').decode().strip()
                release.update(repository=repository,repository_id=current['id'])
                workflow={'run':f'https://github.com/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{os.environ["GITHUB_RUN_ID"]}', 'ref':os.environ['KENNEL_WORKFLOW_REF'], 'sha':os.environ['KENNEL_WORKFLOW_SHA'], 'published_at':datetime.now(timezone.utc).isoformat().replace('+00:00','Z')}
                metadata,artifacts=build(checkout,commit,release,policy,workflow,'https://kennel.kujolang.ai')
                if metadata['package'] != name:
                    raise ValueError('Package identity differs from enrolled name')
                if publish(root,metadata,artifacts):
                    changed.append({'package':name,'version':version,'sha256':metadata['archive_sha256']})
    generate(root)
    print(json.dumps({'published':changed}))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',required=True);p.add_argument('--policy',required=True);p.add_argument('--package',default='');p.add_argument('--release-id',default='');a=p.parse_args();sync(a.root,a.policy,a.package,a.release_id)
