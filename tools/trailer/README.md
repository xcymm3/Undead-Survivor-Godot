# 60 秒宣传片制作

成片：`artifacts/trailer/Undead-Survivor-Trailer-60s-1080p.mp4`。封面为同目录 `poster.jpg`，分镜联系表为 `contact-sheet.jpg`。生成媒体沿用仓库 `artifacts/` 忽略规则，不进入游戏资源或 Git 源码提交。

视频规格为 1920×1080、24 FPS、H.264、AAC 双声道 48 kHz，时长 60 秒；活动画面 1920×804，原始镜头 1600×670，采用超宽画幅和上下黑边。英文游戏名称保留 Undead Survivor。

## 分镜

| 时间 | 画面与节奏 |
| --- | --- |
| 0–3 秒 | 步枪、斧击、舞王三次短切，黑夜降临 |
| 3–8 秒 | 90 只僵尸群推进，面对海量尸潮 |
| 8–15 秒 | 第一人称步枪连续射击、开镜与击杀 |
| 15–17 秒 | 弹药有限 / 战意无穷 |
| 17–24 秒 | 消防斧连续挥砍、原生近战命中与死亡姿态 |
| 24–26 秒 | 舞王登场，音乐断点 |
| 26–34 秒 | 舞王特写、迪斯科跳舞、实际召唤与钻地出现 |
| 34–37 秒 | 步枪展台，持续升级 / 枪械·天赋·防御工事 |
| 37–52 秒 | 步枪、斧击、召唤快切与防线战斗高潮 |
| 52–55 秒 | 镜头拉远，持枪幸存者与水晶防线，坚守到最后一刻 |
| 55–60 秒 | Undead Survivor 标题 / 第一人称增量 FPS / 准备迎战 |

当前升级有等级上限，因此使用“持续升级”，不宣称无限等级。片尾没有添加未经确认的发售日期、Steam 商店地址或平台承诺。

## 画面来源与边界

用户在本次对话中明确授权独立 headless Chromium＋软件渲染。制作只导出临时源码副本，使用真正 headless 的 Godot 导入与 Web 导出；Chromium 强制 headless、SwiftShader、静音，拦截并检查鼠标捕获和全屏请求。不启动本机 Godot 图形进程，不操作桌面，不读取或修改玩家存档。

`capture_scene.gd` 只注入 `build/trailer-source/` 的隔离副本，生产入口没有引用它。僵尸模型、步枪与斧子、武器动作、弹药、射线伤害、近战扫描、死亡姿态、金币效果、舞王跳舞以及 26 只召唤均来自项目原生实现。制作编排了敌人位置、缓慢推进速度、镜头轨迹、灯光和受保护的拍摄角色；步枪采用临时五级弹匣。舞王特写调用原生召唤逻辑并保持舞王在镜头中心，属于宣传镜头编排，不是未经干预的整关录像。

后期加入调色、暗角、短曝光转场、中文字卡、英文标题和程序合成的原创 120 BPM 电子配乐。枪声、斧声、击打与三秒迪斯科提示来自本项目，按每帧记录的事件时间同步；没有使用外部商业歌曲。中文字形使用仓库 Noto Sans CJK SC，遵循 `assets/fonts/LICENSE.txt`。英文优先使用本机 Bahnschrift，缺失时回退到 Noto 字体。

软件 Web 宣传画面不代表原生 GPU 画质、真人体验、性能或正式发布验收。视频画面检查与仓库基础检查分开记录。

## 复现

需要现有 Godot 4.5.2 运行时和 Web 模板、Node.js、已安装的 Playwright headless Chromium，以及 Python 的 Pillow、NumPy、SciPy、imageio-ffmpeg。所有命令在仓库根目录运行：

```powershell
# 后期依赖未安装时：
python -m pip install -r tools/trailer/requirements.txt

# 先生成样片静帧检查构图，导出步骤全部无窗口。
node tools/trailer/capture.mjs --prepare --preview

# 连续录制，输出 960 帧和同步音效事件。
node tools/trailer/capture.mjs --prepare --capture

# 只重拍一组镜头：不更改脚本时可省略 --prepare。
node tools/trailer/capture.mjs --capture --shot=boss

# 合成原创音乐、后期画面、封面与联系表，并完整解码检查成片。
python tools/trailer/edit.py

# 只生成联系表，或只复查已有 MP4。
python tools/trailer/edit.py --preview
python tools/trailer/edit.py --verify
```

分镜时序位于 `edit.py` 的 `EDIT`。原生镜头秒数位于 `capture.mjs` 的 `shots`；同步改变时需要调整 `edit.py` 的帧数验证。单镜头录制生成 `capture-<shot>.json`；已有完整 `capture.json` 时自动替换对应镜头的事件记录。

生成文件包括 `source.json`、`capture.json`、`soundtrack.wav`、`video-report.json`、`decode.log`、`loudness.log` 和 `review.md`。技术验证覆盖完整 MP4 解码、60 秒时长、1080p、24 FPS、完整原始帧数、正击杀数、尸潮数量、舞王 26 只召唤、零页面异常、零鼠标捕获与全屏请求；AAC 编码后的综合响度须为 −19～−12 LUFS，真峰值不高于 −1 dBTP。联系表和原尺寸关键帧仍需实际打开检查；自动断言不替代画面审查。
