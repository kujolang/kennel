import gzip
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/registry'))
from build_package import build, publish, digest, canonical
from generate_registry import generate, version_key
KUJO=os.environ.get('KUJO_BIN','kujo')

class RegistryTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='kennel-registry-test-')
        self.root=Path(self.tmp.name)
        self.repo=self.root/'source';self.repo.mkdir()
        self.git('init','-q');self.git('config','user.name','Fixture');self.git('config','user.email','fixture@example.invalid')
        (self.repo/'kennel.toml').write_text('[package]\nname="fixture"\nversion="1.0.0"\nlicense="MIT"\n[kujo]\nsources=["."]\nexcludes=["ignored"]\n[dependencies]\n')
        (self.repo/'main.kujo').write_text('print("fixture")\n')
        (self.repo/'.env').write_text('FIXTURE_ONLY=not-a-secret\n')
        (self.repo/'ignored').write_text('excluded')
        self.git('add','.');self.git('commit','-qm','fixture');self.git('tag','v1.0.0')
        self.commit=self.git('rev-parse','HEAD').strip()
        self.release={'repository':'kujolang/fixture','repository_id':1,'id':2,'tag_name':'v1.0.0','draft':False,'prerelease':False,'published_at':'2026-01-01T00:00:00Z'}
        self.policy={'packages':{'fixture':{'repository':'kujolang/fixture','repository_id':1,'official':True,'enabled':True}}}
        self.workflow={'published_at':'2026-01-02T00:00:00Z','run':'https://github.com/kujolang/fixture/actions/runs/3','ref':'fixture','sha':self.commit}
    def tearDown(self): self.tmp.cleanup()
    def git(self,*args): return subprocess.check_output(['git','-C',str(self.repo),*args],stderr=subprocess.DEVNULL).decode()
    def build(self): return build(self.repo,self.commit,self.release,self.policy,self.workflow,'https://kennel.kujolang.ai')
    def kujo(self,body,extra_env=None):
        script=self.root/'check.kujo';script.write_text(body)
        env={**os.environ,'KUJO_MODULE_PATH':str(ROOT),**(extra_env or {})}
        return subprocess.run([KUJO,'run',str(script),'--interpreter'],env=env,text=True,capture_output=True)
    def extract(self,blob,count=2):
        source=self.root/'archive.tar.gz';source.write_bytes(blob)
        return self.kujo('from src.registry_archive import extract_registry_archive\nextract_registry_archive(io_read_bytes('+json.dumps(str(source))+',8388608),'+json.dumps(str(self.root/'stage'))+','+str(count)+')\n')
    def archive(self,name='kennel.toml',kind=tarfile.REGTYPE,mode=0o644):
        b=io.BytesIO()
        with tarfile.open(fileobj=b,mode='w',format=tarfile.USTAR_FORMAT) as t:
            i=tarfile.TarInfo(name);i.type=kind;i.mode=mode;i.linkname='../../escape' if kind in (tarfile.SYMTYPE,tarfile.LNKTYPE) else '';i.size=1 if kind==tarfile.REGTYPE else 0;t.addfile(i,io.BytesIO(b'x'))
        return gzip.compress(b.getvalue(),mtime=0)
    def test_deterministic_release_excludes_working_tree_and_secrets(self):
        m,a=self.build();(self.repo/'untracked').write_text('not released');(self.repo/'main.kujo').write_text('dirty')
        m2,a2=self.build();self.assertEqual(a,a2);self.assertEqual(m,m2)
        with tarfile.open(fileobj=io.BytesIO(a['package.tar.gz']),mode='r:gz') as t:
            self.assertEqual(t.getnames(),['kennel.toml','main.kujo'])
        self.assertEqual(self.extract(a['package.tar.gz']).returncode,0)
    def test_immutable_retry_and_mutation(self):
        m,a=self.build();root=self.root/'registry';self.assertTrue(publish(root,m,a));self.assertFalse(publish(root,m,a));generate(root)
        changed=dict(m,archive_sha256='0'*64)
        with self.assertRaisesRegex(ValueError,'mutation'):publish(root,changed,a)
    def test_unauthorized_repository_and_fake_release_fail(self):
        self.release['repository_id']=9
        with self.assertRaises(ValueError):self.build()
        self.release['repository_id']=1;self.release['draft']=True
        with self.assertRaises(ValueError):self.build()
    def test_traversal_absolute_links_modes_invalid_gzip(self):
        for label,blob in [('manifest case',self.archive('KENNEL.TOML')),('traversal',self.archive('../evil')),('absolute',self.archive('/evil')),('symlink',self.archive(kind=tarfile.SYMTYPE)),('hardlink',self.archive(kind=tarfile.LNKTYPE)),('setuid',self.archive(mode=0o4755)),('gzip',b'bad'),('truncated',gzip.compress(b'x'*512)),('excess padding',gzip.compress(gzip.decompress(self.archive())+b'\0'*10240))]:
            with self.subTest(label=label):
                result=self.extract(blob,1);self.assertNotEqual(result.returncode,0,result.stdout);self.assertFalse((self.root/'stage').exists())
    def test_ustar_terminator_can_cross_a_record_boundary(self):
        raw=io.BytesIO()
        with tarfile.open(fileobj=raw,mode='w',format=tarfile.USTAR_FORMAT) as t:
            info=tarfile.TarInfo('kennel.toml');info.size=9216;t.addfile(info,io.BytesIO(b'x'*9216))
        self.assertEqual(len(raw.getvalue())-9728,10752)
        result=self.extract(gzip.compress(raw.getvalue()),1)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_corrupt_header_and_duplicate_paths(self):
        b=bytearray(gzip.decompress(self.archive()));b[0]=ord('z')
        self.assertNotEqual(self.extract(gzip.compress(b),1).returncode,0)
        raw=io.BytesIO()
        with tarfile.open(fileobj=raw,mode='w',format=tarfile.USTAR_FORMAT) as t:
            for _ in range(2):
                i=tarfile.TarInfo('kennel.toml');i.size=1;t.addfile(i,io.BytesIO(b'x'))
        self.assertNotEqual(self.extract(gzip.compress(raw.getvalue())).returncode,0)
    def test_release_symlink_is_rejected_by_builder(self):
        (self.repo/'link').symlink_to('../escape');self.git('add','link');self.git('commit','-qm','link');self.git('tag','-f','v1.0.0');self.commit=self.git('rev-parse','HEAD').strip()
        with self.assertRaisesRegex(ValueError,'link'):self.build()
    def test_metadata_tampering_is_rejected(self):
        m,a=self.build()
        for key,value in [('archive_sha256','wrong'),('official',False),('archive_url','https://evil.invalid/blob'),('file_count',0),('version','01.0.0')]:
            bad=dict(m);bad[key]=value;file=self.root/'manifest.json';file.write_bytes(canonical(bad))
            result=self.kujo('from src.registry_protocol import registry_validate_version\nregistry_validate_version(parse_json(read_file('+json.dumps(str(file))+')), "fixture", "https://kennel.kujolang.ai/api/v1/packages/fixture/1.0.0.json")\n')
            self.assertNotEqual(result.returncode,0,key)

    def test_locked_replay_preserves_manifest_null_and_cache_integrity(self):
        m,a=self.build();home=self.root/'home';cache=home/'.kennel/cache/sha256';cache.mkdir(parents=True)
        for file,key in [('package.tar.gz','archive_sha256'),('provenance.json','provenance_sha256')]:
            (cache/m[key]).write_bytes(a[file])
        url='https://kennel.kujolang.ai/api/v1/packages/fixture/1.0.0.json'
        resolved={'name':'fixture','kind':'registry','source':'registry:'+url,'url':url,'requested':'1.0.0','requested_kind':'version','resolved_ref':'1.0.0','resolved_commit':m['source_commit'],'path':'','checksum':'sha256:'+m['archive_sha256'],'registry':'https://kennel.kujolang.ai/api/v1/index.json','registry_manifest':m,'package_identity':'fixture','provenance_status':'registry-statement-verified'}
        request=self.root/'resolved.json';request.write_bytes(canonical(resolved));project=self.root/'project';project.mkdir()
        body='\n'.join(['from src.installer import install_resolved, install_locked_package','from src.resolver import lock_entry_from_install','from src.lockfile import empty_lockfile, set_packages, save_lockfile, load_lockfile', 'cwd := '+json.dumps(str(project)), 'r := install_resolved(cwd, parse_json(read_file('+json.dumps(str(request))+')))', 'assert_equal(r["ok"], true)', 'save_lockfile(cwd, set_packages(empty_lockfile(), [lock_entry_from_install(r)]))', 'lock := load_lockfile(cwd)["lockfile"]', 'assert_equal(parse_json(lock["package"][0]["registry_manifest"])["scope"], null)', 'replay := install_locked_package(cwd, lock["package"][0])', 'assert_equal(replay["ok"], true)'])
        r=self.kujo(body,{'HOME':str(home)});self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        self.assertEqual((project/'kennel_packages/fixture/main.kujo').read_text(),'print("fixture")\n')
        # A valid digest cache is reusable without any network. Corruption must fail closed.
        call='from src.registry_transport import registry_blob\nregistry_blob("http://invalid.example/package",'+json.dumps(m['archive_sha256'])+',8388608)'
        self.assertEqual(self.kujo(call,{'HOME':str(home)}).returncode,0)
        (cache/m['archive_sha256']).write_bytes(b'corrupt')
        result=self.kujo(call,{'HOME':str(home)});self.assertNotEqual(result.returncode,0);self.assertIn('HTTPS',result.stdout+result.stderr)
        # Independently changing release identity fails provenance consistency checks.
        m['release_id']=999;request.write_bytes(canonical(m))
        r=self.kujo('from src.registry_protocol import registry_verify_provenance\nregistry_verify_provenance(parse_json(read_file('+json.dumps(str(request))+')))',{'HOME':str(home)})
        self.assertNotEqual(r.returncode,0);self.assertIn('provenance mismatch',r.stdout+r.stderr)

    def test_reviewed_manifest_projection_is_commit_and_digest_bound(self):
        source=self.git('show',self.commit+':kennel.toml').encode()
        self.policy['packages']['fixture']['release_manifests']={self.commit:{'source_manifest':'kennel.toml','source_manifest_sha256':__import__('hashlib').sha256(source).hexdigest(),'source_package':'fixture','description':'fixture','entry':'main.kujo'}}
        m,a=self.build()
        p=json.loads(a['provenance.json'])
        self.assertEqual(p['manifest_projection']['source_manifest_sha256'],__import__('hashlib').sha256(source).hexdigest())
        with tarfile.open(fileobj=io.BytesIO(a['package.tar.gz']),mode='r:gz') as t:
            self.assertEqual(t.getnames().count('kennel.toml'),1)
            self.assertEqual(t.extractfile('main.kujo').read(),b'print("fixture")\n')
        self.assertEqual(self.extract(a['package.tar.gz']).returncode,0)
        self.policy['packages']['fixture']['release_manifests'][self.commit]['source_manifest_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'digest mismatch'):self.build()

    def test_manifest_projection_does_not_retarget_dependency_commits(self):
        source=self.git('show',self.commit+':kennel.toml').encode()
        projection={'source_manifest':'kennel.toml','source_manifest_sha256':__import__('hashlib').sha256(source).hexdigest(),'source_package':'fixture','description':'fixture','entry':'main.kujo','dependency_releases':{'missing':{'original':{'source':'github:kujolang/dep','commit':'a'*40},'package':'dep','version':'1.0.0','commit':'a'*40}}}
        self.policy['packages']['fixture']['release_manifests']={self.commit:projection}
        with self.assertRaisesRegex(ValueError,'does not match release source'):self.build()

    def test_prerelease_precedence_is_numeric(self):
        self.assertGreater(version_key('1.0.0-rc.10'), version_key('1.0.0-rc.9'))
        self.assertGreater(version_key('1.0.0'),version_key('1.0.0-rc.10'))

if __name__=='__main__':unittest.main()
