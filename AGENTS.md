# Godot 移植工程约定

- 本目录是独立 Godot 工程。不要修改相邻原项目。
- 玩法与数值来源、已验证范围记录于 `docs/PORTING.md`。不要把 ENet 本地验证称为 Steam 双账号联网验证。
- 场景、渲染与游戏逻辑必须原生运行；资源转换脚本仅用于开发阶段。
- 单人与合作房主使用同一套 `simulation.gd`。客户端不提交权威位置、血量或击杀。
- 河岸、桥梁、落水和寻路共享地形；GPU 敌人动作必须与 CPU 命中姿态一致。
- 用户明确要求编辑期间不干扰桌面。零散检查使用 `tools/validate-headless.ps1`；完整交付必须运行 `npm run verify`，使用 headless Godot 与独立 headless Chromium。不得启动可见编辑器、游戏或网页，不得捕获鼠标、切换全屏或用户桌面焦点。
- 用户已授权当前流程导出 Windows EXE 并推送到 `https://github.com/xcymm3/Undead-Survivor-Godot`，此授权覆盖本次 Actions 的建立和实际运行。EXE 自动检查只能带 `--headless --audio-driver Dummy -- --automation --silent --qa-native-smoke`。
- 提交前运行 `node tools/automation.mjs --check-report`，只接受与当前源码 SHA-256 相符的全绿报告。代码变动后必须重新验证；不要绕过失败门禁或将跳过项目称为通过。`tools/submit.ps1` 可按显式文件清单提交与推送。
- 禁止在用户桌面启动任何 Godot 图形进程，包括 `capture-hidden.ps1`、隐藏父窗口、离屏 SubViewport 及“先启动再隐藏窗口”的方案：这些方案已实际多次弹窗，不能保证不干扰用户。用户要求截图或视觉验收不构成使用这些方案的授权。只能使用已有截图，或另行获得授权的隔离环境；本机检查仅允许真正 headless 的进程。
- 涉及地图、材质、光照、UI、武器或角色显示的任务，测试计划必须包含 `docs/VISUAL_QA.md` 的视觉质量验收。实际打开并检查截图，记录发现、修复和复查证据；截图生成成功、非空白检测、功能全绿都不能替代视觉审查。尚未取得本次 GPU 授权时，将该项明确记为待验收，不能省略或称为通过。
- 只结束本次自己启动的验证进程，不能关闭用户打开的 Godot 编辑器或游戏。
- `npm run verify:release` 完成导出、原生 EXE 无窗口冒烟和 ZIP 打包；正式分发使用 Actions 全绿后的 artifact，不能把导出成功当作游戏验收成功。
- 用户授权默认采用核心回归，以缓存就绪时发布流程10分钟内为目标；完整回归通过 `npm run verify:full` 或 `npm run verify:release:full` 手动执行。报告必须注明配置及未运行项目，核心通过不等于扩展测试或视觉全绿。
- Windows 读取含中文源文件使用 UTF-8。
- Git 主题格式为 `<type>: <简体中文具体摘要>`，英文小写类型，末尾无句号。每次提交只包含一项逻辑相关改动。
- 若配置了远程仓库，完成相关验证后只提交和推送本次改动；不包含用户已有无关改动，不改写历史。未配置远程或推送受阻时说明原因。
