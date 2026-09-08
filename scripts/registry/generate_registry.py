#!/usr/bin/env python3
"""Validate immutable releases, then generate discovery metadata and static pages."""
import argparse
import html
import json
from pathlib import Path
from build_package import canonical, digest, VERSION

CSS = '''*{box-sizing:border-box}body{margin:0;background:#f9f9f9;color:#111;font:16px/1.6 system-ui,sans-serif}a{color:inherit;text-underline-offset:4px}a:hover{color:#555}header,main,footer{max-width:1100px;margin:auto;padding:28px}header{display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #ccc}header a{text-decoration:none}nav{display:flex;gap:24px}.brand{font:700 24px ui-monospace,monospace;letter-spacing:-1px}h1{font-size:clamp(36px,7vw,72px);letter-spacing:-.065em;line-height:1.1;margin:30px 0 20px}h2{letter-spacing:-.035em;font-size:28px}.eyebrow,code,.version{font-family:ui-monospace,monospace}.eyebrow{font-size:14px;text-transform:uppercase;letter-spacing:.1em;color:#555}.intro{max-width:750px;font-size:20px}.command{display:block;background:#111;color:#fff;padding:20px;overflow-wrap:anywhere;margin:28px 0}.search{margin:35px 0}input{width:100%;font:inherit;padding:16px;border:1px solid #888;background:white;border-radius:0}label{display:block;font-weight:600;margin-bottom:8px}.packages{list-style:none;padding:0}.packages li{padding:25px 0;border-top:1px solid #bbb}.packages h2{margin:0;display:flex;justify-content:space-between;gap:20px}.packages p{margin:10px 0}.version{font-size:16px;font-weight:400}.badge{font-size:14px;border:1px solid #888;padding:3px 8px;display:inline-block}.detail{display:grid;grid-template-columns:minmax(0,2fr) minmax(230px,1fr);gap:48px}dl{margin:0}dt{font-weight:650;margin-top:20px}dd{margin:5px 0;overflow-wrap:anywhere}pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:14px}aside{border-left:1px solid #bbb;padding-left:28px}footer{border-top:1px solid #ccc;color:#555;margin-top:60px;font-size:14px}.skip{position:absolute;left:-10000px}.skip:focus{left:20px}button,input,a{outline-offset:5px}[hidden]{display:none!important}@media(max-width:700px){header,main,footer{padding:20px}.detail{grid-template-columns:1fr;gap:20px}aside{border-left:0;padding:0;border-top:1px solid #bbb}nav{gap:14px;font-size:14px}.packages h2{font-size:24px}}'''
SEARCH = """const input=document.querySelector('#search');if(input)input.addEventListener('input',()=>{let n=0;for(const item of document.querySelectorAll('[data-package]')){item.hidden=!item.textContent.toLowerCase().includes(input.value.toLowerCase());if(!item.hidden)n++;}document.querySelector('#count').textContent=n+' packages';});"""


def esc(v):
    return html.escape(str(v), quote=True)


def page(title, content, path='', description='Official released packages for Kujo.'):
    return f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{esc(title)} · Kennel</title><meta name="description" content="{esc(description)}"><link rel="canonical" href="https://kennel.kujolang.ai/{esc(path)}"><link rel="stylesheet" href="/style.css"><script src="/search.js" defer></script></head><body><a class="skip" href="#main">Skip to content</a><header><a class="brand" href="/">KENNEL<span aria-hidden="true">_</span></a><nav aria-label="Main"><a href="/">Packages</a><a href="/api/v1/index.json">Registry JSON</a><a href="https://kujolang.ai">Kujo ↗</a></nav></header><main id="main">{content}</main><footer>Official Kujo package registry. Released source, immutable artifacts.<br>Development happens on GitHub. Distribution happens here.</footer></body></html>'


def version_key(version):
    match = VERSION.fullmatch(version)
    if not match:
        raise ValueError('Malformed version')
    pre=match.group(4)
    identifiers=tuple((0,int(p)) if p.isdigit() else (1,p) for p in pre.split('.')) if pre else ()
    return tuple(map(int, match.groups()[:3])) + (pre is None, identifiers)


def generate(root):
    root = Path(root)
    summaries = []
    catalog_path = root.parent/'catalog.json'
    catalog = json.loads(catalog_path.read_bytes()).get('packages', {}) if catalog_path.exists() else {}
    for package_dir in sorted((root / 'packages').iterdir()) if (root / 'packages').exists() else []:
        versions = []
        for manifest_path in package_dir.glob('*/manifest.json'):
            m = json.loads(manifest_path.read_bytes())
            folder = manifest_path.parent
            if m['package'] != package_dir.name or m['version'] != folder.name:
                raise ValueError('Package directory identity mismatch')
            for file, field in [('package.tar.gz', 'archive_sha256'), ('provenance.json', 'provenance_sha256')]:
                if digest((folder/file).read_bytes()) != m[field]:
                    raise ValueError(f'Corrupt immutable artifact: {folder/file}')
            machine = root/'api/v1/packages'/m['package']/(m['version']+'.json')
            checksums = f'{m["archive_sha256"]}  package.tar.gz\n{m["provenance_sha256"]}  provenance.json\n'.encode()
            if (folder/'checksums.txt').read_bytes() != checksums:
                raise ValueError('Checksum file differs from immutable manifest')
            if machine.read_bytes() != manifest_path.read_bytes():
                raise ValueError('Version metadata differs from immutable manifest')
            versions.append(m)
        versions.sort(key=lambda m: version_key(m['version']), reverse=True)
        if not versions:
            continue
        stable = [m for m in versions if '-' not in m['version']]
        latest = stable[0] if stable else versions[0]
        name = latest['package']
        summary = {'schema_version':1, 'name':name, 'scope':None, 'owner':latest['owner'], 'official':True, 'description':latest['description'], 'latest':stable[0]['version'] if stable else '', 'metadata_path':f'packages/{name}.json'}
        if name in catalog:
            description = catalog[name].get('description', latest['description'])
            if not isinstance(description, str) or not description.strip():
                raise ValueError('Catalog description must be nonempty text')
            summary['description'] = description
        metadata = {**summary, 'versions':[{'version':m['version'],'metadata_url':f'https://kennel.kujolang.ai/api/v1/packages/{name}/{m["version"]}.json','archive_sha256':m['archive_sha256'],'yanked':False} for m in versions]}
        (root/'api/v1/packages'/f'{name}.json').write_bytes(canonical(metadata))
        summaries.append(summary)
        for m in versions:
            render_package(root, m, versions, f'{name}/{m["version"]}')
        render_package(root, {**latest, 'description': summary['description']}, versions, name)
        text = f'# {name}\n\n{summary["description"]}\n\nInstall: `kennel add {name}`\n\nLatest stable: {summary["latest"] or "none"}\n\nVersions: '+', '.join(m['version'] for m in versions)+f'\n\nMetadata: https://kennel.kujolang.ai/api/v1/packages/{name}.json\n\nProvenance: {latest["provenance_url"]}\n\nArchive SHA-256: {latest["archive_sha256"]}\n\nDependencies: '+json.dumps(latest['dependencies'])+'\n'
        (root/f'{name}.md').write_text(text)
    (root/'api/v1').mkdir(parents=True, exist_ok=True)
    (root/'api/v1/index.json').write_bytes(canonical({'schema_version':1,'registry':'https://kennel.kujolang.ai','packages':summaries}))
    rows=''.join(f'<li data-package><h2><a href="/{s["name"]}">{s["name"]}</a><span class="version">{s["latest"] or "prerelease"}</span></h2><p>{esc(s["description"])}</p><span class="badge">Official · kujolang</span></li>' for s in summaries)
    body=f'<p class="eyebrow">The Kujo package registry</p><h1>Find your next tool.</h1><p class="intro">Install released Kujo packages with verified checksums and traceable source.</p><code class="command">kennel add changebucket</code><div class="search"><label for="search">Search official packages</label><input id="search" type="search" placeholder="Package name or description" aria-describedby="count"><p id="count" role="status">{len(summaries)} packages</p></div><ul class="packages">{rows}</ul>'
    (root/'index.html').write_text(page('Official Kujo packages',body))
    (root/'style.css').write_text(CSS)
    (root/'search.js').write_text(SEARCH)
    (root/'404.html').write_text(page('Package not found','<h1>Package not found.</h1><p><a href="/">Browse official packages</a></p>'))
    (root/'robots.txt').write_text('User-agent: *\nAllow: /\n')
    (root/'_headers').write_text('/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n  Content-Security-Policy: default-src \'self\'; object-src \'none\'; base-uri \'none\'; frame-ancestors \'none\'\n/api/v1/*\n  Content-Type: application/json\n  Cache-Control: public, max-age=60\n/packages/*\n  Cache-Control: public, max-age=31536000, immutable\n')
    print(json.dumps({'packages':len(summaries),'index_bytes':(root/'api/v1/index.json').stat().st_size}))


def render_package(root, m, versions, route):
    name, version = m['package'], m['version']
    links=' · '.join(f'<a href="/{name}/{v["version"]}">{v["version"]}</a>' for v in versions)
    exact=route != name
    command=f'kennel add {name}'+('@'+version if exact else '')
    fields=[('Version',version),('License',m['license'] or 'Not declared in this release'),('Released',m['released_at']),('Download',f'{m["archive_size"]:,} bytes · {m["file_count"]} files'),('SHA-256',m['archive_sha256']),('Source commit',m['source_commit'])]
    info=''.join(f'<dt>{esc(k)}</dt><dd>{esc(v)}</dd>' for k,v in fields)
    body=f'<p class="eyebrow"><a href="/">Packages</a> / {name}'+(f' / {version}' if exact else '')+f'</p><h1>{name}</h1><span class="badge">Official · kujolang</span><p class="intro">{esc(m["description"])}</p><code class="command">{command}</code><div class="detail"><section><h2>Release {version}</h2><p><a href="{m["archive_url"]}">Download package.tar.gz</a> · <a href="/api/v1/packages/{name}/{version}.json">Exact release JSON</a> · <a href="/{name}.md">Markdown</a></p><h2>Versions</h2><p>{links}</p><h2>Dependencies</h2><pre>{esc(json.dumps(m["dependencies"],indent=2)) if m["dependencies"] else "No package dependencies."}</pre><h2>Provenance</h2><p>Release identity and archive digest are recorded in the <a href="{m["provenance_url"]}">publishing statement</a>. The registry is the trust authority; this statement is not an independent signature.</p><p>Source project: <a href="https://github.com/{esc(m["repository"])}">{esc(m["repository"])}</a> · release ID {m["release_id"]}</p></section><aside><h2>Package details</h2><dl>{info}</dl><p><a href="{m["checksum_url"]}">Checksum file</a></p></aside></div>'
    target=root/route/'index.html';target.parent.mkdir(parents=True,exist_ok=True);target.write_text(page(name+(' '+version if exact else ''),body,route,m['description']))


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('root');generate(parser.parse_args().root)
