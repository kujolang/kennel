"""Generate installer delivery and onboarding from the current publisher checkout."""
import hashlib
import io
import json
from pathlib import Path
import tarfile


def generate_onboarding(root, page):
    installer = (Path(__file__).resolve().parent.parent/'install.py').read_bytes()
    (root/'install.py').write_bytes(installer)
    checksum = hashlib.sha256(installer).hexdigest()
    shell = '''#!/bin/sh
set -eu
command -v python3 >/dev/null 2>&1 || { echo 'Kennel requires Python 3.9+ and Kujo 1.3.1+.' >&2; exit 1; }
installer_dir=$(mktemp -d)
trap 'rm -rf "$installer_dir"' EXIT HUP INT TERM
curl --fail --silent --show-error --proto '=https' --connect-timeout 10 --max-time 60 https://kennel.kujolang.ai/install.py -o "$installer_dir/install.py"
python3 - "$installer_dir/install.py" <<'PY'
import hashlib, pathlib, sys
if hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest() != 'CHECKSUM':
    raise SystemExit('Installer checksum mismatch; download install.sh again.')
PY
python3 "$installer_dir/install.py" "$@"
'''.replace('CHECKSUM',checksum)
    (root/'install.sh').write_text(shell)
    ready = False
    package = root/'api/v1/packages/kennel.json'
    if package.exists():
        latest = json.loads(package.read_bytes()).get('latest')
        archive = root/'packages/kennel'/str(latest)/'package.tar.gz'
        if archive.is_file():
            with tarfile.open(archive,'r:gz') as tar:
                try:
                    marker = json.load(tar.extractfile('scripts/bootstrap.json'))
                    ready = marker.get('installer_protocol') == 1
                except KeyError:
                    pass
    notice = '' if ready else '<p class="badge">Release preview — the first installer-enabled Kennel release is pending.</p><p>The installer is ready for review but will reject historical releases. Maintainers can test <code>python3 scripts/install.py --source .</code> from the current Kennel checkout. No new release has been published.</p>'
    body = '<p class="eyebrow">Getting started</p><h1>Install once.<br>Use everywhere.</h1>'+notice+'''<p>Requires macOS or Linux, <a href="https://kujolang.ai/ecosystem/kujo/">Kujo 1.3.1+</a>, Python 3.9+ and curl. No administrator access is needed. The installer adds ~/.kennel/bin to Bash, Zsh and POSIX shell profiles.</p><h2>Install Kennel</h2><pre><code>curl -fsSLO https://kennel.kujolang.ai/install.sh
sh install.sh
. "$HOME/.kennel/env"
kennel --version</code></pre><p>You can inspect install.sh and <a href="/install.py">install.py</a> before running them. Use <code>sh install.sh --no-modify-path</code> to configure PATH yourself. Fish users can run <code>fish_add_path ~/.kennel/bin</code>.</p><h2>Global tools</h2><pre><code>kennel tool install shipcheck
shipcheck --help
kennel tool list
kennel tool update shipcheck
kennel tool remove shipcheck</code></pre><p>Tools run from your current directory. Installation creates user-owned commands and records exact package versions and checksums. Existing commands are protected. An exact version stays pinned; use <code>kennel tool install shipcheck@1.0.0</code> to select it explicitly.</p><h2>Project dependencies</h2><pre><code>kennel init --name my-project
kennel add ability
kennel install</code></pre><p>Project dependencies stay inside the project and do not add global commands.</p><h2>Keep Kennel updated</h2><pre><code>kennel self update</code></pre><p>This selects the latest stable installer-compatible official release. A failed update preserves your current client and global tools. Pin a client with <code>kennel self update --version VERSION</code>.</p><h2>Publish a tool</h2><p>Enrolled official projects publish through actual GitHub Releases. Keep kennel.toml and the release tag version aligned; the registry checks new releases every 15 minutes. Declare commands explicitly:</p><pre><code>[bin]
my-tool = "main.kujo"</code></pre><p>Entries must be included .kujo files or executable sh, Bash or Python 3 scripts with supported shebangs. Historical packages may use their existing [kujo].entry instead. Libraries with no executable entry are installed with kennel add.</p>'''
    target=root/'getting-started/index.html';target.parent.mkdir(exist_ok=True);target.write_text(page('Getting started',body,'getting-started','Install Kennel, manage global Kujo tools, and add project dependencies.'))
