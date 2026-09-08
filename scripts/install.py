#!/usr/bin/env python3
"""Install a released Kennel client, or a reviewed source checkout, without sudo."""
import argparse
import contextlib
import fcntl
import hashlib
import gzip
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import uuid

REGISTRY = 'https://kennel.kujolang.ai'
MAX_ARCHIVE = 8 * 1024 * 1024
MAX_EXPANDED = 64 * 1024 * 1024


def fetch(url, limit):
    if not url.startswith(REGISTRY+'/') or any(ord(c)<32 for c in url):
        raise ValueError('Installer artifacts must use the official HTTPS registry')
    process = subprocess.Popen(['curl','--fail','--silent','--show-error','--proto','=https',
                                '--connect-timeout','10','--max-time','60',url], stdout=subprocess.PIPE)
    try:
        data = process.stdout.read(limit+1)
        if len(data)>limit:
            raise ValueError('Registry response exceeds installer limit')
        if process.wait()!=0:
            raise ValueError('Registry download failed: '+url)
        return data
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        process.stdout.close()



def sha(data):
    return hashlib.sha256(data).hexdigest()


def extract(data, target):
    # Do not use extractall: reject links, special types, traversal and duplicates first.
    with gzip.GzipFile(fileobj=io.BytesIO(data)) as compressed:
        raw = compressed.read(MAX_EXPANDED+1)
    if len(raw)>MAX_EXPANDED:
        raise ValueError('Installer archive exceeds expanded size limit')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:') as archive:
        total = 0
        seen = set()
        entries = []
        for member in archive:
            parts = PurePosixPath(member.name).parts
            if (not parts or member.name.startswith('/') or '..' in parts or '\\' in member.name
                    or any(ord(c)<32 for c in member.name) or str(PurePosixPath(member.name)).casefold() in seen
                    or not member.isfile() or member.issparse() or member.pax_headers or member.size<0 or member.mode & 0o7000):
                raise ValueError('Unsafe installer archive member: '+member.name)
            seen.add(str(PurePosixPath(member.name)).casefold())
            total += member.size
            if total>MAX_EXPANDED or len(seen)>10000:
                raise ValueError('Installer archive exceeds extraction limit')
            entries.append(member)
        for member in entries:
            path = target.joinpath(*PurePosixPath(member.name).parts)
            path.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(member) as source, path.open('xb') as dest:
                shutil.copyfileobj(source,dest)
            path.chmod(0o755 if member.mode & 0o111 else 0o644)


def download_client(version, target):
    if version is None:
        package = json.loads(fetch(REGISTRY+'/api/v1/packages/kennel.json', 1024*1024))
        version = package.get('latest')
    if not isinstance(version,str) or not re.fullmatch(r'\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?',version):
        raise ValueError('Invalid or unavailable Kennel release version')
    manifest = json.loads(fetch(REGISTRY+'/api/v1/packages/kennel/'+version+'.json', 1024*1024))
    if (manifest.get('schema_version')!=1 or manifest.get('package')!='kennel'
            or manifest.get('version')!=version or manifest.get('official') is not True
            or manifest.get('scope') is not None or manifest.get('owner')!={'type':'organization','id':'kujolang'}):
        raise ValueError('Invalid official Kennel release identity')
    archive = fetch(manifest['archive_url'], MAX_ARCHIVE)
    if len(archive)!=manifest['archive_size'] or sha(archive)!=manifest['archive_sha256']:
        raise ValueError('Kennel archive checksum/size mismatch')
    provenance_bytes = fetch(manifest['provenance_url'],1024*1024)
    if sha(provenance_bytes)!=manifest['provenance_sha256']:
        raise ValueError('Kennel provenance checksum mismatch')
    provenance = json.loads(provenance_bytes)
    # Validate the registry's provenance shape below using the same release bindings.
    if provenance.get('schema_version')!=1 or not str(provenance.get('workflow_run','')).startswith('https://github.com/kujolang/kennel-registry/actions/runs/') or not re.fullmatch(r'[0-9a-f]{40}',str(provenance.get('workflow_sha',''))):
        raise ValueError('Invalid official publishing workflow provenance')
    for key in ['package','version','source_commit','source_tag','repository','repository_id','release_id','archive_sha256']:
        if provenance.get(key)!=manifest.get(key):
            raise ValueError('Kennel provenance identity mismatch: '+key)
    extract(archive,target)
    return {'version':version,'archive_sha256':sha(archive),'registry':REGISTRY}


def copy_source(source, target):
    required = ['kennel.kujo','kennel.toml','bin/kennel','scripts/tool_manager.py','scripts/tool_metadata.kujo','scripts/bootstrap.json']
    for relative in required:
        if not (source/relative).is_file():
            raise ValueError('Not an installable Kennel checkout: '+relative)
    # Copy only tracked inputs. Never caches, untracked local files or repository internals.
    names = subprocess.check_output(['git','-C',str(source),'ls-files','-z']).decode().split('\0')
    for name in names:
        if not name or any(part in {'.git','.kennel_tmp','kennel_packages','node_modules'} for part in Path(name).parts):
            continue
        path=source/name
        if path.is_symlink():
            raise ValueError('Source install cannot include symbolic links: '+name)
        if path.is_file():
            dest=target/name; dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,dest)
            dest.chmod(0o755 if path.stat().st_mode & 0o111 else 0o644)
    return {'source':str(source),'review_build':True}


def profile_text(base):
    return '# Kennel PATH\ncase ":${PATH:-}:" in *'+shlex.quote(':'+str(base/'bin')+':')+'*) ;; *) export PATH='+shlex.quote(str(base/'bin'))+':"${PATH:-}" ;; esac\n'


def setup_path(base, user_home):
    env=base/'env'
    if env.is_symlink():
        raise ValueError('Refusing to overwrite symlinked Kennel environment file')
    env.write_text(profile_text(base))
    block='\n# >>> Kennel PATH >>>\n. '+shlex.quote(str(env))+'\n# <<< Kennel PATH <<<\n'
    for name in ['.profile','.bash_profile','.bashrc','.zshrc']:
        path=user_home/name
        if path.is_symlink():
            raise ValueError('Refusing to change symlinked shell profile; use --no-modify-path: '+str(path))
        old=path.read_text() if path.exists() else ''
        if '# >>> Kennel PATH >>>' in old:
            updated=re.sub(r'\n?# >>> Kennel PATH >>>\n.*?\n# <<< Kennel PATH <<<\n?',block,old,flags=re.S)
        else:
            updated=old+block
        if updated!=old:
            path.write_text(updated)


def main(argv=None):
    parser=argparse.ArgumentParser(description='Install Kennel for macOS/Linux. Requires Kujo 1.3.1+, Python 3.9+, and curl.')
    group=parser.add_mutually_exclusive_group()
    group.add_argument('--version',help='Exact released Kennel version (default: latest stable)')
    group.add_argument('--source',type=Path,help='Install a reviewed local Git checkout instead of a release')
    parser.add_argument('--home',type=Path,default=Path(os.environ.get('KENNEL_HOME',str(Path.home()/'.kennel'))))
    parser.add_argument('--no-modify-path',action='store_true',help='Leave shell profiles unchanged; print PATH setup')
    args=parser.parse_args(argv)
    if os.name!='posix' or sys.version_info<(3,9):
        raise ValueError('Installer requires macOS/Linux and Python 3.9+')
    kujo=shutil.which(os.environ.get('KUJO_BIN','kujo'))
    if not kujo:
        raise ValueError('Install Kujo 1.3.1+ first: https://kujolang.ai/ecosystem/kujo/')
    version=subprocess.check_output([kujo,'--version'],text=True)
    match=re.search(r'(\d+)\.(\d+)\.(\d+)',version)
    if not match or tuple(map(int,match.groups()))<(1,3,1):
        raise ValueError('Kujo 1.3.1+ is required; installed runtime: '+version.strip())
    base=args.home.expanduser().absolute()
    if any(p.is_symlink() for p in [base,*base.parents]):
        raise ValueError('Installation directory must not traverse symbolic links')
    base.mkdir(parents=True,exist_ok=True,mode=0o700)
    with (base/'.tools.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        clients=base/'clients';clients.mkdir(exist_ok=True)
        bindir=base/'bin';bindir.mkdir(exist_ok=True)
        if clients.is_symlink() or bindir.is_symlink():
            raise ValueError('Installation subdirectories cannot be symbolic links')
        launcher=bindir/'kennel'
        expected='#!/bin/sh\n# Kennel managed client\nexport KENNEL_HOME='+shlex.quote(str(base))+'\nexec '+shlex.quote(str(base/'client/bin/kennel'))+' "$@"\n'
        if os.path.lexists(launcher) and (launcher.is_symlink() or launcher.read_text()!=expected):
            raise ValueError('Refusing to overwrite an existing kennel command: '+str(launcher))
        current=base/'client'
        if os.path.lexists(current) and not current.is_symlink():
            raise ValueError('Existing client directory is not managed by this installer')
        if not args.no_modify_path:
            for n in ['.profile','.bash_profile','.bashrc','.zshrc']:
                if (Path.home()/n).is_symlink():
                    raise ValueError('Shell profile is a symlink; use --no-modify-path')
        stage=Path(tempfile.mkdtemp(prefix='client-',dir=clients))
        committed=False
        try:
            receipt=copy_source(args.source.resolve(),stage) if args.source else download_client(args.version,stage)
            marker=stage/'scripts/bootstrap.json'
            if not marker.is_file() or json.loads(marker.read_text()).get('installer_protocol')!=1:
                raise ValueError('This historical Kennel release predates the installer. Wait for the upcoming release or use --source for review.')
            for relative in ['bin/kennel','kennel.kujo','scripts/tool_manager.py','scripts/tool_metadata.kujo']:
                if not (stage/relative).is_file():
                    raise ValueError('Incomplete Kennel client: '+relative)
            (stage/'bin/kennel').chmod(0o755)
            subprocess.run([kujo,'run',str(stage/'kennel.kujo'),'--interpreter','--','help'],check=True,stdout=subprocess.DEVNULL)
            (stage/'install-receipt.json').write_text(json.dumps(receipt,sort_keys=True,indent=2)+'\n')
            # Profiles are prepared before activation; existing installations remain intact on failure.
            if not args.no_modify_path:
                setup_path(base,Path.home())
            link=base/('.client-'+uuid.uuid4().hex)
            link.symlink_to(stage.relative_to(base),target_is_directory=True)
            if not launcher.exists():
                with launcher.open('x') as f:f.write(expected)
                launcher.chmod(0o755)
            os.replace(link,current)
            committed=True
        finally:
            if not committed:shutil.rmtree(stage)
    print('Kennel installed in '+str(base))
    print('For this terminal: export PATH='+shlex.quote(str(base/'bin'))+':"$PATH"')
    print('Next: kennel tool install shipcheck')
    if args.source:print('Review build installed; no official release was published.')


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,subprocess.SubprocessError,KeyError,TypeError,tarfile.TarError) as exc:
        print('Kennel installer: '+str(exc),file=sys.stderr);sys.exit(1)
