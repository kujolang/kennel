"""OS integration and bootstrap threat-boundary regressions (no network)."""
import gzip
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parent.parent

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value

installer=module('bootstrap','scripts/install.py')
tools=module('global_tools','scripts/tool_manager.py')

class GlobalTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.base=Path(self.temp.name).resolve()
    def tearDown(self):self.temp.cleanup()
    def archive(self,entries):
        raw=io.BytesIO()
        with tarfile.open(fileobj=raw,mode='w',format=tarfile.USTAR_FORMAT) as tar:
            for name,data,kind in entries:
                info=tarfile.TarInfo(name);info.size=len(data);info.type=kind
                tar.addfile(info,io.BytesIO(data))
        return gzip.compress(raw.getvalue())
    def test_extract_regular_file(self):
        installer.extract(self.archive([('src/main.kujo',b'print(1)',tarfile.REGTYPE)]),self.base)
        self.assertEqual((self.base/'src/main.kujo').read_bytes(),b'print(1)')
    def test_archive_rejects_escapes_links_and_duplicates(self):
        for entries in [[('../escape',b'x',tarfile.REGTYPE)],[('/escape',b'x',tarfile.REGTYPE)],
                        [('symlink',b'',tarfile.SYMTYPE)],[('hardlink',b'',tarfile.LNKTYPE)],
                        [('a',b'x',tarfile.REGTYPE),('./a',b'y',tarfile.REGTYPE)],
                        [('A',b'x',tarfile.REGTYPE),('a',b'y',tarfile.REGTYPE)]]:
            with self.subTest(entries=entries),self.assertRaises(ValueError):
                installer.extract(self.archive(entries),self.base)
    def test_expanded_limit(self):
        with patch.object(installer,'MAX_EXPANDED',100),self.assertRaises(ValueError):
            installer.extract(gzip.compress(b'x'*101),self.base)
    def test_invalid_archive(self):
        with self.assertRaises((OSError,tarfile.TarError)):
            installer.extract(b'not gzip',self.base)
    def test_foreign_host_rejected_before_network(self):
        with self.assertRaises(ValueError):installer.fetch('http://kennel.kujolang.ai/x',10)
        with self.assertRaises(ValueError):installer.fetch('https://evil.example/x',10)
    def test_checksum_mismatch_stops_before_extraction(self):
        m={'schema_version':1,'package':'kennel','version':'2.0.0','official':True,'scope':None,
           'owner':{'type':'organization','id':'kujolang'},'archive_url':installer.REGISTRY+'/archive',
           'archive_size':3,'archive_sha256':'0'*64}
        with patch.object(installer,'fetch',side_effect=[json.dumps(m).encode(),b'bad']),\
                patch.object(installer,'extract') as extraction,self.assertRaisesRegex(ValueError,'checksum'):
            installer.download_client('2.0.0',self.base)
        extraction.assert_not_called()
    def test_command_map_and_library_rejection(self):
        (self.base/'main.kujo').write_text('print(1)')
        self.assertEqual(tools.command_map(self.base,{'package':{'name':'demo'},'kujo':{'entry':'main.kujo'}}),{'demo':'main.kujo'})
        self.assertEqual(tools.command_map(self.base,{'bin':{'one':'main.kujo','two':'main.kujo'}}),{'one':'main.kujo','two':'main.kujo'})
        with self.assertRaises(ValueError):tools.command_map(self.base,{'package':{'name':'library'}})
    def test_entry_traversal_symlinks_and_reserved_commands(self):
        (self.base/'main.kujo').write_text('print(1)');(self.base/'linked.kujo').symlink_to(self.base/'main.kujo')
        for entry in ['../main.kujo','/main.kujo','linked.kujo','missing.kujo','x.sh']:
            with self.subTest(entry=entry),self.assertRaises(ValueError):tools.safe_entry(self.base,entry)
        for command in ['kennel','kujo','sh','bad/name','--bad']:
            with self.subTest(command=command),self.assertRaises(ValueError):tools.command_map(self.base,{'bin':{command:'main.kujo'}})
    def test_conflict_keeps_existing_state_and_command(self):
        (self.base/'bin').mkdir();target=self.base/'bin/demo';target.write_text('user command')
        state={'schema_version':1,'packages':{}}
        with self.assertRaises(ValueError):tools.activate(self.base,state,'demo',{'commands':{'demo':'main.kujo'}})
        self.assertEqual(target.read_text(),'user command');self.assertFalse((self.base/'tools.json').exists())
    def test_command_ownership_collision(self):
        state={'schema_version':1,'packages':{'first':{'commands':{'demo':'main.kujo'}}}}
        with self.assertRaises(ValueError):tools.activate(self.base,state,'second',{'commands':{'demo':'main.kujo'}})
    def test_failed_activation_rolls_back_new_shims(self):
        state={'schema_version':1,'packages':{}}
        with patch.object(tools,'save_state',side_effect=OSError('disk full')),patch.object(tools.shutil,'which',return_value=None),self.assertRaises(OSError):
            tools.activate(self.base,state,'demo',{'commands':{'demo':'main.kujo'}})
        self.assertFalse((self.base/'bin/demo').exists())
    def test_atomic_activation_and_update(self):
        state={'schema_version':1,'packages':{}}
        with patch.object(tools.shutil,'which',return_value=None):
            tools.activate(self.base,state,'demo',{'version':'1','commands':{'demo':'main.kujo'}})
            tools.activate(self.base,state,'demo',{'version':'2','commands':{'new-demo':'main.kujo'}})
        self.assertEqual(tools.load_state(self.base)['packages']['demo']['version'],'2')
        self.assertFalse((self.base/'bin/demo').exists());self.assertTrue((self.base/'bin/new-demo').exists())
    def test_path_setup_idempotent_preserves_user_content(self):
        base=self.base/'install space';base.mkdir()
        profile=self.base/'.zshrc';profile.write_text('export USER_SETTING=keep\n')
        installer.setup_path(base,self.base);before=profile.read_bytes();installer.setup_path(base,self.base)
        self.assertEqual(before,profile.read_bytes());self.assertIn(b'USER_SETTING=keep',before)
        code='. '+str(self.base/'.profile')+'; . '+str(self.base/'.profile')+'; printf "%s" "$PATH"'
        result=subprocess.check_output(['/bin/sh','-c',code],env={'PATH':'/usr/bin:/bin'},text=True)
        self.assertEqual(result.count(str(base/'bin')),1)
    def test_profile_symlink_rejected(self):
        (self.base/'.profile').symlink_to(self.base/'elsewhere')
        with self.assertRaises(ValueError):installer.setup_path(self.base,self.base)

if __name__=='__main__':unittest.main()
