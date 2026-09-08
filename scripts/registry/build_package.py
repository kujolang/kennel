#!/usr/bin/env python3
"""Build a normalized release package from Git objects, never a working tree."""
import argparse
import fnmatch
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
try:
    import tomllib
except ImportError:
    import tomli as tomllib

MAX_ARCHIVE = 8 * 1024 * 1024
MAX_EXPANDED = 64 * 1024 * 1024
MAX_FILES = 10000
NAME = re.compile(r'[a-z0-9][a-z0-9_-]{0,63}\Z')
VERSION = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?\Z')
DENY = {'.git', '.env', '.kennel_tmp', '.kennel', 'kennel_packages', 'node_modules', 'target', 'dist', 'build', '__pycache__', '.DS_Store', '.idea', '.vscode', '.cache', 'artifacts'}


def canonical(obj):
    return (json.dumps(obj, sort_keys=True, indent=2, ensure_ascii=True) + '\n').encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])


def safe_path(name):
    if not name or len(name) > 240 or not name.isascii() or any(ord(c) < 32 for c in name):
        raise ValueError(f'Unsafe package path: {name!r}')
    if '\\' in name or ':' in name or name.startswith('/') or any(p in ('', '.', '..') or p.endswith((' ', '.')) for p in name.split('/')):
        raise ValueError(f'Unsafe package path: {name!r}')
    if any(p.split('.')[0].upper() in {'CON', 'PRN', 'AUX', 'NUL', *('COM'+str(i) for i in range(10)), *('LPT'+str(i) for i in range(10))} for p in name.split('/')):
        raise ValueError(f'Nonportable package path: {name!r}')
    return name


def matches(path, patterns):
    return any(p == '.' or path == p.rstrip('/') or path.startswith(p.rstrip('/') + '/') or fnmatch.fnmatchcase(path, p) for p in patterns)


def toml_document(document):
    """Canonical TOML for reviewed release-manifest projection (no null values)."""
    lines = []
    def emit(table, path):
        if path:
            lines.append('[' + '.'.join(json.dumps(k) for k in path) + ']')
        for key, value in sorted(table.items()):
            if not isinstance(value, dict):
                if value is None:
                    raise ValueError('Null is not a TOML value')
                lines.append(json.dumps(key) + ' = ' + json.dumps(value, ensure_ascii=True))
        for key, value in sorted(table.items()):
            if isinstance(value, dict):
                emit(value, path + [key])
    emit(document, [])
    return ('\n'.join(lines) + '\n').encode()


def build(repo, commit, release, policy, workflow, base):
    commit = git(repo, 'rev-parse', '--verify', commit + '^{commit}').decode().strip()
    legacy = None
    synthetic_manifest = None
    tracked = git(repo, 'ls-tree', '--name-only', commit).decode().splitlines()
    projections = [(n, p.get('release_manifests', {}).get(commit)) for n, p in policy['packages'].items() if p.get('repository') == release['repository']]
    projections = [(n, p) for n, p in projections if p]
    projection = None
    if projections:
        if len(projections) != 1:
            raise ValueError('Ambiguous release manifest projection')
        name, projection = projections[0]
        source = projection.get('source_manifest')
        source_bytes = git(repo, 'show', commit + ':' + source) if source else b''
        if digest(source_bytes) != projection['source_manifest_sha256']:
            raise ValueError('Release manifest projection source digest mismatch')
        original = tomllib.loads(source_bytes.decode()) if source else {}
        manifest = json.loads(json.dumps(original))
        package = manifest.setdefault('package', dict(original.get('project', {})))
        if package.get('name', name) != projection.get('source_package', name):
            raise ValueError('Unexpected source package identity')
        version = release['tag_name'].removeprefix('v')
        if package.get('version', version) != version:
            raise ValueError('Source manifest version differs from actual release')
        package.update(name=name, version=version)
        package.setdefault('description', projection['description'])
        package.setdefault('license', projection.get('license', ''))
        controls = manifest.setdefault('kujo', {})
        controls.setdefault('entry', projection.get('entry', ''))
        controls.setdefault('sources', ['.'])
        dependencies = manifest.setdefault('dependencies', {})
        for dep, target in projection.get('dependency_releases', {}).items():
            declared = dependencies.get(dep)
            if declared != target['original']:
                raise ValueError('Dependency projection does not match release source')
            approved = policy['packages'].get(target['package'], {})
            if target['commit'] != approved.get('release_commits', {}).get(target['version']):
                raise ValueError('Dependency commit is not an approved release')
            pinned = declared.get('commit', declared.get('ref', ''))
            if pinned != target['commit'] or declared.get('source') != 'github:' + approved['repository']:
                raise ValueError('Dependency release changes the pinned source')
            dependencies[dep] = {'source': 'registry:' + base + '/api/v1/packages/' + target['package'] + '/' + target['version'] + '.json'}
        synthetic_manifest = toml_document(manifest)
    else:
        if 'kennel.toml' in tracked:
            manifest = tomllib.loads(git(repo, 'show', commit + ':kennel.toml').decode())
        else:
            allowed = [(n, p.get('legacy_releases', {}).get(commit)) for n, p in policy['packages'].items() if p.get('repository') == release['repository']]
            allowed = [(n, p) for n, p in allowed if p]
            if len(allowed) != 1:
                raise ValueError('Release has no kennel.toml and no commit-pinned legacy packaging policy')
            name, legacy = allowed[0]
            original = tomllib.loads(git(repo, 'show', commit + ':' + legacy['source_manifest']).decode())
            if original['package']['name'] != legacy['source_package'] or original.get('dependencies', {}):
                raise ValueError('Unexpected legacy package identity/dependencies')
            version = original['package']['version']
            synthetic_manifest = ('[package]\nname = ' + json.dumps(name) + '\nversion = ' + json.dumps(version) + '\ndescription = ' + json.dumps(legacy['description']) + '\nlicense = ""\n[kujo]\nentry = ' + json.dumps(legacy['entry']) + '\nsources = ["."]\n[dependencies]\n').encode()
            manifest = tomllib.loads(synthetic_manifest.decode())
    package = manifest['package']
    name, version = package['name'], package['version']
    if not NAME.fullmatch(name) or not VERSION.fullmatch(version):
        raise ValueError('Invalid package name or SemVer')
    pre = VERSION.fullmatch(version).group(4)
    if pre and any(p.isdigit() and len(p) > 1 and p.startswith('0') for p in pre.split('.')):
        raise ValueError('Invalid prerelease SemVer')
    entry = policy['packages'].get(name, {})
    repository = release['repository']
    if not (entry.get('enabled') is True and entry.get('official') is True and entry.get('repository') == repository and entry.get('repository_id') == release['repository_id'] and repository.startswith('kujolang/')):
        raise ValueError('Release repository is not authorized for this package')
    if release.get('draft') is not False or release['tag_name'].removeprefix('v') != version or bool(pre) != release['prerelease']:
        raise ValueError('Published release tag/channel does not match package version')
    if not isinstance(release['id'], int) or not release['published_at']:
        raise ValueError('Actual published GitHub Release required')
    tag_commit = git(repo, 'rev-parse', '--verify', 'refs/tags/' + release['tag_name'] + '^{commit}').decode().strip()
    if tag_commit != commit:
        raise ValueError('Release tag does not match exact source commit')
    controls = manifest.get('kujo', {})
    include = controls.get('sources', ['.']) + controls.get('includes', []) + ['kennel.toml', 'LICENSE']
    exclude = controls.get('excludes', [])
    if not all(isinstance(p, str) for p in include + exclude):
        raise ValueError('Packaging controls must be string arrays')
    files, seen, total = [], set(), 0
    for record in git(repo, 'ls-tree', '-rz', '--full-tree', commit).split(b'\0'):
        if not record:
            continue
        header, raw_name = record.split(b'\t', 1)
        mode, kind, oid = header.decode().split()
        path = raw_name.decode('utf-8')
        parts = PurePosixPath(path).parts
        if any(p in DENY or p.startswith('.env.') or p.endswith(('.pem', '.key', '.p12', '.pyc', '.swp', '~')) for p in parts):
            continue
        if not matches(path, include) or matches(path, exclude):
            continue
        safe_path(path)
        if path.lower() in seen or kind != 'blob' or mode not in ('100644', '100755'):
            raise ValueError(f'Unsupported link/submodule or colliding file: {path}')
        seen.add(path.lower())
        if path == 'kennel.toml' and synthetic_manifest is not None:
            continue
        data = git(repo, 'cat-file', 'blob', oid)
        total += len(data)
        if total > MAX_EXPANDED - 1024 * MAX_FILES or len(files) >= MAX_FILES:
            raise ValueError('Package exceeds expanded size/file limit')
        files.append((path, data, 0o755 if mode == '100755' else 0o644))
    if synthetic_manifest is not None:
        files.append(('kennel.toml', synthetic_manifest, 0o644))
    if not any(p == 'kennel.toml' for p, _, _ in files):
        raise ValueError('Package must include kennel.toml')
    commands = manifest.get('bin', {})
    if not isinstance(commands, dict):
        raise ValueError('[bin] must map command names to packaged .kujo entries')
    packaged_paths = {path for path, _, _ in files}
    for command, entrypoint in commands.items():
        if not re.fullmatch(r'[a-z][a-z0-9_-]{0,63}', command) or not isinstance(entrypoint, str):
            raise ValueError('Invalid executable command declaration')
        safe_path(entrypoint)
        if not entrypoint.endswith('.kujo') or entrypoint not in packaged_paths:
            raise ValueError('Executable entry is not included in package: '+entrypoint)
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode='w', format=tarfile.USTAR_FORMAT) as archive:
        for path, data, mode in sorted(files):
            info = tarfile.TarInfo(path)
            info.size, info.mode, info.mtime = len(data), mode, 0
            info.uid = info.gid = 0
            info.uname = info.gname = ''
            archive.addfile(info, io.BytesIO(data))
    out = io.BytesIO()
    with gzip.GzipFile(fileobj=out, mode='wb', filename='', mtime=0, compresslevel=9) as zipped:
        zipped.write(raw.getvalue())
    blob = out.getvalue()
    if len(blob) > MAX_ARCHIVE or len(raw.getvalue()) > MAX_EXPANDED:
        raise ValueError('Package exceeds archive limits')
    prefix = f'{base}/packages/{name}/{version}'
    provenance = {'schema_version': 1, 'package': name, 'version': version, 'source_commit': commit, 'source_tag': release['tag_name'], 'repository': repository, 'repository_id': release['repository_id'], 'release_id': release['id'], 'released_at': release['published_at'], 'published_at': workflow['published_at'], 'workflow_run': workflow['run'], 'workflow_ref': workflow['ref'], 'workflow_sha': workflow['sha'], 'archive_sha256': digest(blob), 'builder': 'kennel-ustar-gzip-v1'}
    if legacy:
        provenance['legacy_packaging'] = {'source_manifest': legacy['source_manifest'], 'source_package': legacy['source_package'], 'generated_file': 'kennel.toml', 'generated_file_sha256': digest(synthetic_manifest)}
    if projection:
        provenance['manifest_projection'] = {'source_manifest': projection.get('source_manifest'), 'source_manifest_sha256': projection['source_manifest_sha256'], 'generated_file': 'kennel.toml', 'generated_file_sha256': digest(synthetic_manifest), 'dependency_releases': projection.get('dependency_releases', {})}
    provenance_bytes = canonical(provenance)
    metadata = {'schema_version': 1, 'package': name, 'version': version, 'scope': None, 'owner': {'type': 'organization', 'id': 'kujolang'}, 'official': True, 'description': package.get('description', ''), 'license': package.get('license', ''), 'released_at': release['published_at'], 'source_commit': commit, 'source_tag': release['tag_name'], 'archive_url': prefix + '/package.tar.gz', 'archive_sha256': digest(blob), 'archive_size': len(blob), 'file_count': len(files), 'provenance_url': prefix + '/provenance.json', 'provenance_sha256': digest(provenance_bytes), 'checksum_url': prefix + '/checksums.txt', 'dependencies': manifest.get('dependencies', {}), 'minimum_kujo_version': controls.get('minimum_version', ''), 'repository': repository, 'repository_id': release['repository_id'], 'release_id': release['id']}
    return metadata, {'package.tar.gz': blob, 'manifest.json': canonical(metadata), 'provenance.json': provenance_bytes, 'checksums.txt': f'{digest(blob)}  package.tar.gz\n{digest(provenance_bytes)}  provenance.json\n'.encode()}


def publish(root, metadata, artifacts):
    target = Path(root) / 'packages' / metadata['package'] / metadata['version']
    if target.exists():
        old = json.loads((target / 'manifest.json').read_bytes())
        # Retry timestamps/run IDs may differ. Preserve the first complete publication.
        if any(old.get(k) != metadata[k] for k in ('archive_sha256', 'source_commit', 'release_id', 'repository_id')) or (target / 'package.tar.gz').read_bytes() != artifacts['package.tar.gz']:
            raise ValueError('Immutable package version mutation rejected')
        for name in artifacts:
            if not (target / name).is_file():
                raise ValueError('Incomplete existing publication; explicit recovery required')
        return False
    target.mkdir(parents=True)
    for name, data in artifacts.items():
        (target / name).write_bytes(data)
    version_path = Path(root) / 'api/v1/packages' / metadata['package'] / (metadata['version'] + '.json')
    version_path.parent.mkdir(parents=True, exist_ok=True)
    version_path.write_bytes(artifacts['manifest.json'])
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for arg in ('repo', 'commit', 'release', 'policy', 'workflow', 'output'):
        parser.add_argument('--' + arg, required=True)
    parser.add_argument('--base', default='https://kennel.kujolang.ai')
    args = parser.parse_args()
    metadata, artifacts = build(args.repo, args.commit, json.loads(Path(args.release).read_bytes()), json.loads(Path(args.policy).read_bytes()), json.loads(Path(args.workflow).read_bytes()), args.base.rstrip('/'))
    changed = publish(args.output, metadata, artifacts)
    print(json.dumps({'package': metadata['package'], 'version': metadata['version'], 'sha256': metadata['archive_sha256'], 'changed': changed}))


if __name__ == '__main__':
    main()
