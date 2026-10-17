import assert from 'node:assert/strict';
import {test} from 'node:test';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {execFileSync} from 'node:child_process';

test('native project paths install a Git-backed local dependency and retain the lockfile',()=>{
 const root=mkdtempSync(join(tmpdir(),'kennel-native-'));const runtime=process.env.KUJO_BIN;assert.ok(runtime);
 const git=(args,cwd)=>execFileSync('git',args,{cwd,stdio:'pipe'});
 try{
  const dependency=join(root,'dependency'),project=join(root,'project with spaces');mkdirSync(dependency);mkdirSync(project);
  writeFileSync(join(dependency,'kennel.toml'),'[package]\nname = "native-dep"\nversion = "1.0.0"\n');
  git(['init'],dependency);git(['add','.'],dependency);git(['-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-m','fixture'],dependency);
  const manifest='[package]\nname = "native-project"\nversion = "1.0.0"\n[dependencies]\nnative-dep = { path = '+JSON.stringify(dependency)+' }\n';
  writeFileSync(join(project,'kennel.toml'),manifest);
  const run=command=>execFileSync(runtime,['run',resolve('kennel.kujo'),'--interpreter','--',command,'--project-dir',project],{cwd:project,timeout:120000});
  run('install');
  assert.match(readFileSync(join(project,'kennel_packages','native-dep','kennel.toml'),'utf8'),/native-dep/);
  const stable=()=>readFileSync(join(project,'kennel.lock'),'utf8').replace(/^generated_at.*\n/m,'');const before=stable();
  run('install');assert.equal(stable(),before);
 }finally{rmSync(root,{recursive:true,force:true});}
});
