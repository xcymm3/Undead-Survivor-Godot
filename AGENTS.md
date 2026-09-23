# Godot 移植工程约定

- 本目录是独立 Godot 工程。不要修改相邻原项目。
- 玩法与数值来源、已验证范围记录于 `docs/PORTING.md`。不要把 ENet 本地验证称为 Steam 双账号联网验证。
- 场景、渲染与游戏逻辑必须原生运行；资源转换脚本仅用于开发阶段。
- 单人与合作房主使用同一套 `simulation.gd`。客户端不提交权威位置、血量或击杀。
- 河岸、桥梁、落水和寻路共享地形；GPU 敌人动作必须与 CPU 命中姿态一致。
- 用户明确要求编辑期间不干扰桌面。日常修改默认运行 `npm run verify` 基础检查，并按改动范围使用 `tools/validate-headless.ps1` 补充专项检查。用户明确要求在本地“验收”“全量测试”时才运行 `npm run verify:full`；正式发布 Windows EXE 的全量验收、导出和打包交给 GitHub Actions，不在本地重复运行 `npm run verify:release`。只有用户明确要求本地生成 EXE 或本地发布验收时，才在本地运行 `npm run verify:release`。不得启动可见编辑器、游戏或网页，不得捕获鼠标、切换全屏或用户桌面焦点。
- 用户已授权当前流程导出 Windows EXE 并推送到 `https://github.com/xcymm3/Undead-Survivor-Godot`，此授权覆盖本次 Actions 的建立和实际运行。EXE 自动检查只能带 `--headless --audio-driver Dummy -- --automation --silent --qa-native-smoke`。
- 提交前运行 `node tools/automation.mjs --check-report`，只接受与当前源码 SHA-256 相符的全绿基础或全量报告。代码变动后必须重新运行基础检查；不要把未执行的全量、视觉或发布项目称为通过。`tools/submit.ps1` 可按显式文件清单提交与推送。
- 禁止在用户桌面启动任何 Godot 图形进程，包括 `capture-hidden.ps1`、隐藏父窗口、离屏 SubViewport 及“先启动再隐藏窗口”的方案：这些方案已实际多次弹窗，不能保证不干扰用户。用户要求截图或视觉验收不构成使用这些方案的授权。只能使用已有截图，或另行获得授权的隔离环境；本机检查仅允许真正 headless 的进程。
- 只有用户明确要求视觉验收或截图审查时，才执行 `docs/VISUAL_QA.md`。生成截图时仍须实际打开检查；截图生成成功、非空白检测和功能检查不能替代视觉审查。
- 只结束本次自己启动的验证进程，不能关闭用户打开的 Godot 编辑器或游戏。
- 发布 Windows EXE 时，先在本地完成基础检查及相关专项检查，提交并推送本次源码；再由 GitHub Actions 对该提交运行 `npm run verify:release`，完成全量技术门禁、Windows 导出、原生 EXE 无窗口冒烟和 ZIP 打包。当前工作流在 `main` 分支、`v*` 标签、PR 或手动触发时运行，推送其他分支本身不会触发。检查 Actions 的结果与源码提交一致且全绿后，正式分发使用其 artifact；不能把导出成功当作游戏验收成功。脚本试玩、Steam 双账号联网、原生 GPU 画面和真人体验不属于当前自动发布门禁。
- `npm run verify` 只运行快速基础检查；`npm run verify:full` 运行水晶防线、弹道、Web 导出和浏览器技术检查，不打包 Windows EXE。报告必须注明配置及未运行项目，基础检查通过不等于全量、视觉或发布验收通过。
- Windows 读取含中文源文件使用 UTF-8。
- Git 主题格式为 `<type>: <简体中文具体摘要>`，英文小写类型，末尾无句号。每次提交只包含一项逻辑相关改动。
- 若配置了远程仓库，完成相关验证后只提交和推送本次改动；不包含用户已有无关改动，不改写历史。未配置远程或推送受阻时说明原因。
