# Blender AK 模型源工程

`ak47.blend` 是本次制作的可编辑源文件，`build_ak47.py` 是其离线重建脚本。
使用 Blender 4.5.15 LTS 后台运行脚本，将同时保存源工程和 `assets/models/ak47.glb`。
`.gdignore` 防止 Godot 在导入游戏时再次调用 Blender；游戏和 CI 只加载已导出的 GLB。

```powershell
blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/blender/build_ak47.py
```

建模坐标采用米制、游戏 Y 向上、枪口朝 -Z，脚本转换至 Blender Z 向上，导出时转换回 glTF Y 向上。
主体、弧形弹匣和拉机柄为三个独立网格；原枪口、左右握持点和模型尺度保留。
网格共 9,232 个三角面，使用六种共享材质；不承诺相比旧模型提高运行帧率。
所有几何与材质在 Blender 中制作并烘焙，运行时脚本仅加载模型和驱动活动部件。

第一人称、队友、展台和拾取显示共用模型工厂。换弹和拉机柄继续由现有武器时钟驱动；
枪托攻击调整第一人称持枪轨迹，权威推击距离、伤害、冷却和 0.32 秒动作窗口不变。
模型为本项目原创，不包含第三方网格或纹理。

按需运行 `preparation-visual.yml` 的 `ak_rifle` 范围，在隔离 Actions runner 中以 Godot Web / Chromium SwiftShader
录制开火、换弹和枪托攻击；每个 GIF 按记录的 20 FPS 编码。固定镜头、初始弹药和近景补光属于审查布置，
不是整关试玩、Steam 双账号联机或原生 GPU 验收。
