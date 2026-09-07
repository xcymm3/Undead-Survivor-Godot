# Godot 移植工程约定

- 本目录是独立 Godot 工程。不要修改相邻原项目。
- 玩法与数值来源、已验证范围记录于 `docs/PORTING.md`。不要把 ENet 本地验证称为 Steam 双账号联网验证。
- 场景、渲染与游戏逻辑必须原生运行；资源转换脚本仅用于开发阶段。
- 单人与合作房主使用同一套 `simulation.gd`。客户端不提交权威位置、血量或击杀。
- 河岸、桥梁、落水和寻路共享地形；GPU 敌人动作必须与 CPU 命中姿态一致。
- 用户明确要求编辑期间不干扰桌面。零散检查使用 `tools/validate-headless.ps1`；完整交付必须运行 `npm run verify`，使用 headless Godot 与独立 headless Chromium。不得启动可见编辑器、游戏或网页，不得捕获鼠标、切换全屏或用户桌面焦点。
- 用户已授权当前流程导出 Windows EXE 并推送到 `https://github.com/xcymm3/Undead-Survivor-Godot`，此授权覆盖本次 Actions 的建立和实际运行。EXE 自动检查只能带 `--headless --audio-driver Dummy -- --automation --silent --qa-native-smoke`。
- 提交前运行 `node tools/automation.mjs --check-report`，只接受与当前源码 SHA-256 相符的全绿报告。代码变动后必须重新验证；不要绕过失败门禁或将跳过项目称为通过。`tools/submit.ps1` 可按显式文件清单提交与推送。
- 不自动运行 GPU 截图，包括 `capture-hidden.ps1`、`capture.gd` 及“先启动再隐藏窗口”的替代方式。图形进程可能在初始化时闪现；只有用户明确要求本次视觉验收或主动试玩时才可启动，并提前说明此限制。
- 只结束本次自己启动的验证进程，不能关闭用户打开的 Godot 编辑器或游戏。
- `npm run verify:release` 完成导出、原生 EXE 无窗口冒烟和 ZIP 打包；正式分发使用 Actions 全绿后的 artifact，不能把导出成功当作游戏验收成功。
- Windows 读取含中文源文件使用 UTF-8。
- Git 主题格式为 `<type>: <简体中文具体摘要>`，英文小写类型，末尾无句号。每次提交只包含一项逻辑相关改动。
- 若配置了远程仓库，完成相关验证后只提交和推送本次改动；不包含用户已有无关改动，不改写历史。未配置远程或推送受阻时说明原因。
