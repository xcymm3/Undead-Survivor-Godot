import {cp,mkdir,readFile,writeFile,symlink,access} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
const root=process.cwd(),dest=path.join(root,'artifacts/visual-project');
await mkdir(dest,{recursive:true});
for(const dir of ['assets','scenes','scripts'])await cp(dir,path.join(dest,dir),{recursive:true});
for(const file of ['project.godot','export_presets.cfg','icon.svg'])await cp(file,path.join(dest,file));
await mkdir(path.join(dest,'tools'),{recursive:true});await cp('tools/web-shell.html',path.join(dest,'tools/web-shell.html'));
try {await access(path.join(dest,'.runtime'));}catch{await symlink(path.join(root,'.runtime'),path.join(dest,'.runtime'),'junction');}
let source=await readFile('scripts/main.gd','utf8');
source=source.replace('func _ready() -> void:', 'func _ready() -> void:\n\tcall_deferred("_start_visual")');
source+=`\nfunc _start_visual() -> void:
\tstart_solo("practice")
\tset_physics_process(false)
\tsim.zombies.clear()
\tsim.add_pawn("visual","模型验收",1)
\tsim.pawns.visual.pos = Vector2(0,5)
\tsim.pawns.visual.appearance = [0,2,3]
\tData.settings.resolution = 1.0
\tData.settings.pixelated = false
\tData.apply_settings()
\tvar stage = load("res://scripts/visual_fixture.gd").new()
\tstage.game = self
\tstage.process_priority = 100
\tadd_child(stage)
`;
await writeFile(path.join(dest,'scripts/main.gd'),source);
await cp('tools/visual-fixture.gd',path.join(dest,'scripts/visual_fixture.gd'));
await mkdir(path.join(dest,'build/web'),{recursive:true});
const engine=path.join(root,'.runtime/Godot_v4.5.2-stable_win64_console.exe');
for(const args of [['--editor','--import','--quit'],['--export-release','Web QA']])execFileSync(engine,['--headless','--audio-driver','Dummy','--path',dest,...args],{windowsHide:true,stdio:'pipe',timeout:180000});
console.log('Prepared isolated visual project: '+dest);
