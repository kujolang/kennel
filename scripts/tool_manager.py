#!/usr/bin/env python3
"""POSIX command activation; resolution, verification and extraction stay in Kujo."""
import argparse
import contextlib
import fcntl
from functools import lru_cache
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parent.parent
NAME = re.compile(r'[a-z][a-z0-9_-]{0,63}\Z')
RESERVED = {'kennel', 'kujo', 'sh', 'bash', 'zsh', 'fish', 'python', 'python3', 'env'}


def home():
    result = Path(os.environ.get('KENNEL_HOME', str(Path.home()/'.kennel'))).expanduser().absolute()
    if any(p.is_symlink() for p in [result, *result.parents]):
        raise ValueError('KENNEL_HOME must not traverse symbolic links')
    result.mkdir(parents=True, exist_ok=True, mode=0o700)
    return result


@lru_cache(maxsize=1)
def runtime():
    value = os.environ.get('KUJO_BIN', 'kujo')
    found = shutil.which(value)
    if not found:
        raise ValueError('Kujo 1.3.1+ is required; install Kujo or set KUJO_BIN')
    if '--isolated-imports' not in subprocess.check_output([found, 'run', '--help'], text=True):
        raise ValueError('This Kujo runtime lacks --isolated-imports; use the updated Kujo source build until its next release')
    return str(Path(found).absolute())


def native(*args, capture=False):
    result = subprocess.run([runtime(), 'run', str(ROOT/'kennel.kujo'), '--interpreter', '--isolated-imports', '--', *map(str,args)],
                            capture_output=capture, text=True, env={**os.environ, 'KUJO_MODULE_PATH': str(ROOT), 'KUJO_ISOLATED_IMPORTS': '1'})
    if result.returncode:
        raise ValueError((result.stderr or result.stdout or 'Kennel dependency operation failed').strip())
    return result.stdout


def metadata(path):
    result = subprocess.run([runtime(), 'run', str(ROOT/'scripts/tool_metadata.kujo'), '--interpreter', '--', str(path)],
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def load_state(base):
    path = base/'tools.json'
    if not path.exists():
        return {'schema_version': 1, 'packages': {}}
    data = json.loads(path.read_text())
    if data.get('schema_version') != 1 or not isinstance(data.get('packages'), dict):
        raise ValueError('Unsupported or invalid global tool state')
    return data


def save_state(base, state):
    path = base/('.tools-'+uuid.uuid4().hex+'.json')
    path.write_text(json.dumps(state, sort_keys=True, indent=2)+'\n')
    os.chmod(path, 0o600)
    os.replace(path, base/'tools.json')


@contextlib.contextmanager
def transaction(base):
    with (base/'.tools.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def safe_entry(package, entry):
    if not isinstance(entry, str) or not entry or '\\' in entry or any(ord(c)<32 for c in entry):
        raise ValueError('Invalid tool entry path')
    path = PurePosixPath(entry)
    if path.is_absolute() or '..' in path.parts:
        raise ValueError('Tool entries must be relative packaged files without traversal')
    target = package.joinpath(*path.parts)
    if any(p.is_symlink() for p in [target, *target.parents]) or not target.is_file():
        raise ValueError('Tool entry must be a regular packaged file: '+entry)
    target.resolve().relative_to(package.resolve())
    if target.suffix != ".kujo":
        entry_argv(target)
    return entry


def entry_argv(target):
    if target.suffix == '.kujo':
        return [runtime(), 'run', str(target), '--interpreter', '--isolated-imports', '--']
    with target.open('rb') as source:
        shebang = source.readline(256).rstrip(b'\r\n')
    interpreters = {b'#!/bin/sh': '/bin/sh', b'#!/usr/bin/env sh': '/bin/sh',
                    b'#!/bin/bash': '/bin/bash', b'#!/usr/bin/env bash': '/bin/bash',
                    b'#!/usr/bin/env python3': shutil.which('python3'), b'#!/usr/bin/python3': shutil.which('python3')}
    interpreter = interpreters.get(shebang)
    if not interpreter or not target.stat().st_mode & 0o111:
        raise ValueError('Entry must be .kujo or an executable sh/bash/python3 script with a supported shebang')
    return [interpreter, str(target)]


def command_map(package, manifest, command=None):
    declared = manifest.get('bin')
    if declared is None:
        entry = manifest.get('kujo', {}).get('entry', '')
        if not entry:
            raise ValueError('Package has no executable entry; use kennel add for libraries')
        declared = {command or manifest['package']['name']: entry}
    elif command:
        if len(declared) != 1:
            raise ValueError('--command requires a single executable')
        declared = {command: next(iter(declared.values()))}
    if not isinstance(declared, dict) or not declared:
        raise ValueError('[bin] must map command names to .kujo entry files')
    for name, entry in declared.items():
        if not NAME.fullmatch(name) or name in RESERVED:
            raise ValueError('Unsafe or reserved global command: '+name)
        safe_entry(package, entry)
    return dict(sorted(declared.items()))


def shim(base, command):
    # A stable launcher reads the single atomic state pointer at invocation time.
    return '#!/bin/sh\n# Kennel managed tool command\nexec '+shlex.quote(str(base/'bin/kennel'))+' tool run --command '+shlex.quote(command)+' -- "$@"\n'


def owned(path, expected):
    return path.is_file() and not path.is_symlink() and path.read_text() == expected


def activate(base, state, name, record, allow_shadow=False):
    bindir = base/'bin'
    bindir.mkdir(exist_ok=True)
    if bindir.is_symlink():
        raise ValueError('Global bin directory cannot be a symbolic link')
    for command in record['commands']:
        target = bindir/command
        for other, installed in state['packages'].items():
            if other != name and command in installed['commands']:
                raise ValueError(f'Command {command} belongs to {other}')
        if os.path.lexists(target) and not owned(target, shim(base, command)):
            raise ValueError('Refusing to overwrite existing command: '+str(target))
        existing = shutil.which(command)
        if existing and Path(existing).absolute() != target.absolute() and not allow_shadow:
            raise ValueError(f'Command {command} already exists on PATH; use --allow-shadow to opt in')
    old = state['packages'].get(name, {})
    created = []
    try:
        for command in record['commands']:
            target = bindir/command
            if not target.exists():
                # Exclusive create prevents overwriting commands from another installer.
                with target.open('x') as f:
                    f.write(shim(base, command))
                target.chmod(0o755)
                created.append(target)
        state['packages'][name] = record
        save_state(base, state)
    except BaseException:
        for path in created:
            path.unlink(missing_ok=True)
        raise
    for command in old.get('commands', {}):
        path = bindir/command
        if command not in record['commands'] and owned(path, shim(base, command)):
            path.unlink()


def install(base, spec, command=None, allow_shadow=False):
    if spec.startswith('file:'):
        spec = 'file:'+str(Path(spec[5:]).expanduser().resolve())
    elif spec.startswith(('.', '/')):
        spec = 'file:'+str(Path(spec).expanduser().resolve())
    # One isolated generation per install. Old generations remain for running processes.
    generations = base/'tools'
    generations.mkdir(exist_ok=True)
    if generations.is_symlink():
        raise ValueError('Tool storage cannot be a symbolic link')
    stage = Path(tempfile.mkdtemp(prefix='generation-', dir=generations))
    committed = False
    try:
        native('init', '--name', 'kennel-global-tool', '--project-dir', stage, capture=True)
        native('add', spec, '--project-dir', stage)
        lock = metadata(stage/'kennel.lock')
        manifest = metadata(stage/'kennel.toml')
        dependencies = manifest.get('dependencies', {})
        if len(dependencies) != 1:
            raise ValueError('Expected exactly one top-level tool package')
        name = next(iter(dependencies))
        if not NAME.fullmatch(name):
            raise ValueError('Global package identity must be an unscoped safe name')
        package = stage/'kennel_packages'/name
        source = metadata(package/'kennel.toml')
        minimum = source.get('kujo', {}).get('minimum_version', '1.3.1') or '1.3.1'
        required = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)', minimum)
        installed = re.search(r'(\d+)\.(\d+)\.(\d+)', subprocess.check_output([runtime(), '--version'],text=True))
        if not required or not installed or tuple(map(int, installed.groups())) < tuple(map(int, required.groups())):
            raise ValueError('Tool requires Kujo '+minimum+' or newer')
        commands = command_map(package, source, command)
        entries = lock['package']
        roots = []
        for entry in entries:
            relative = entry['install_path']
            parts = PurePosixPath(relative).parts
            if len(parts)!=2 or parts[0]!='kennel_packages' or not NAME.fullmatch(parts[1]):
                raise ValueError('Invalid locked tool dependency path')
            roots.append(str(stage.joinpath(*parts)))
        selected = next(p for p in entries if p['name']==name)
        record = {'spec': spec, 'version': source['package']['version'], 'generation': stage.name,
                  'commands': commands, 'command_override': command, 'module_roots': [str(package)]+[r for r in roots if r!=str(package)],
                  'lock': selected}
        state = load_state(base)
        activate(base, state, name, record, allow_shadow)
        committed = True
        print(f'Installed {name} {record["version"]}: '+', '.join(commands))
    finally:
        if not committed:
            shutil.rmtree(stage)


def run_tool(base, command, args):
    state = load_state(base)
    for name, record in state['packages'].items():
        if command in record['commands']:
            generation = base/'tools'/record['generation']
            package = generation/'kennel_packages'/name
            entry = safe_entry(package, record['commands'][command])
            env = os.environ.copy()
            env['KUJO_MODULE_PATH'] = os.pathsep.join(record['module_roots'])
            env['KUJO_ISOLATED_IMPORTS'] = '1'
            env['KUJO_BIN'] = runtime()
            env.pop('KUJO_SCRIPT_ARGS_JSON', None)
            env.pop('KUJO_SCRIPT_ARGS', None)
            invocation = entry_argv(package/entry)
            os.execve(invocation[0], [*invocation, *args], env)
    raise ValueError('Global command is not installed: '+command)


def main(argv=None):
    parser = argparse.ArgumentParser(prog='kennel tool', description='Install Kujo commands into ~/.kennel/bin')
    sub = parser.add_subparsers(dest='action', required=True)
    for action in ['install', 'update']:
        p = sub.add_parser(action)
        p.add_argument('package', nargs='?' if action=='update' else None)
        p.add_argument('--command')
        p.add_argument('--allow-shadow', action='store_true')
    sub.add_parser('list')
    p = sub.add_parser('remove'); p.add_argument('package')
    p = sub.add_parser('run'); p.add_argument('--command', required=True);p.add_argument('args', nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    base = home()
    if args.action=='run':
        run_tool(base, args.command, args.args[1:] if args.args[:1]==['--'] else args.args)
        return
    with transaction(base):
        state = load_state(base)
        if args.action=='list':
            for name, record in sorted(state['packages'].items()):
                print(name+' '+record['version']+'  '+', '.join(record['commands']))
        elif args.action=='install':
            install(base, args.package, args.command, args.allow_shadow)
        elif args.action=='update':
            names = [args.package] if args.package else sorted(state['packages'])
            for name in names:
                if name not in state['packages']:
                    raise ValueError('Tool not installed; use kennel tool install PACKAGE@VERSION to select a version')
                record = state['packages'][name]
                install(base, record['spec'], args.command or record['command_override'], args.allow_shadow)
        elif args.action=='remove':
            if args.package not in state['packages']:
                raise ValueError('Tool not installed: '+args.package)
            record = state['packages'].pop(args.package)
            save_state(base, state)
            for command in record['commands']:
                path = base/'bin'/command
                if owned(path, shim(base, command)):
                    path.unlink()
            print('Removed '+args.package)


if __name__=='__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError, KeyError, TypeError) as exc:
        print('kennel tool: '+str(exc), file=sys.stderr)
        sys.exit(1)
