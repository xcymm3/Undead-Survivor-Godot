# 自动修改与验收流程

仓库：https://github.com/xcymm3/Undead-Survivor-Godot

## 每次修改

1. AI 根据需求修改代码，补充相关规则或浏览器回归场景。
2. 运行 `npm run verify`：准备固定引擎和 Web 模板、导入、规则检查、双人和四人 ENet、导出 Web、无界面 Chromium 真实输入试玩。
3. 查看 `artifacts/acceptance.md` 与浏览器截图、日志、trace。任何失败都修复重跑；报告记录源码 SHA-256，修改源码后旧报告失效。
4. 确认报告后运行 `node tools/automation.mjs --check-report`，只提交本次相关文件并推送。当前会话用户已授权提交推送；如后续明确要求人工确认，则在推送前等待确认。
5. GitHub Actions 对 main 推送、PR、版本标签或手动触发重新验收，通过后导出 Windows、运行成品 EXE 的无窗口冒烟检查、打包 ZIP，上传构建产物。

本流程由当前 AI 会话执行修改与修复，Actions 负责确定性验证和打包；没有配置可自行接受自然语言需求或调用付费模型的云端 AI 服务。

## 首次准备（Windows / Node.js 22 / PowerShell 7）

```powershell
npm ci
npx playwright install chromium --only-shell
npm run verify
```

下载地址和校验值锁定在 `tools/setup-runtime.ps1` 与 `tools/setup-web-templates.ps1`，首次需下载较大的官方模板包。后续使用本机缓存；Actions 缓存所需引擎与 Web 模板。Node 依赖由 package-lock.json 锁定。

完整流程显式使用 `pwsh.exe`，避免从 PowerShell 7 启动旧版 Windows PowerShell 时继承不兼容的模块搜索路径；GitHub 的 windows-2022 环境自带 PowerShell 7。

本机也可完整打包，仍不打开可见窗口：

```powershell
npm run verify:release
```

按显式文件清单提交的示例（先根据本次改动填写文件）：

```powershell
./tools/submit.ps1 -Message 'fix: 修复换弹期间的武器切换' -Files scripts/simulation.gd,tools/validate-runtime.gd
```

## 浏览器实际验证什么

- 点击真实 Godot 菜单：设置、武器说明、多人入口、练习、单人、排行榜。
- 通过浏览器键盘移动、跳跃、换弹、切换全部十款武器、暂停与继续；通过鼠标转向、射击及开镜。
- 真实子弹命中练习目标，验证伤害、击杀、弹药消耗及装填恢复。
- 正式关卡自然刷怪、敌人接近和攻击，玩家实际死亡、结算与重开。
- 保存真实 WebGL 渲染截图，检查不是空白画面；保存浏览器错误、交互 trace 和只读游戏状态。
- 鼠标锁和全屏 API 被拒绝并计数：即使调用未成功，也使验收失败。测试不得使用可见浏览器、`--headed` 或用户现有浏览器会话。

`scripts/automation_observer.gd` 仅在 `--automation` 启用时发布只读状态，没有向网页提供传送、修改血量或代替输入的接口。自动化模式不读取或写入玩家存档，静音，不启用鼠标锁/全屏；鼠标移动经同一灵敏度与视角计算路径处理。

Web QA 是测试导出，使用同一场景、规则、资源和输入代码。其专用 HTML 传入自动化参数并禁用桌面干扰操作。Windows 普通启动继续使用正常玩家模式。

## 下载与失败定位

**玩家下载入口：[GitHub Releases](https://github.com/xcymm3/Undead-Survivor-Godot/releases/latest)。** main 分支推送或手动运行验收成功后，以 `build-<运行序号>` 发布；`v*` 标签构建沿用该标签。PR 仅验证，不发布。发布任务只在前置验收成功后运行，校验下载包哈希，先上传草稿附件再公开，避免出现空 Release。

Release 同时提供完整 ZIP、独立 EXE、Steam DLL、appid 和许可文件。推荐 ZIP；单独下载 EXE 时必须同时下载 DLL 与 appid。构建报告仍位于以下 Actions 入口。

仓库 **Actions → Godot 自动验收与 Windows 打包 → 对应运行 → Artifacts**：

- `acceptance-<commit>`：每阶段日志、验收 JSON/Markdown、浏览器截图、HTML 报告和 trace；失败也上传。
- `Undead-Survivor-Godot-Windows-x64-<commit>`：仅全部成功后上传，含 ZIP 和 SHA256SUMS.txt。解压内层 ZIP 后运行 EXE，Steam DLL 与 appid 必须随包保留。

HTML 报告不会自动打开。需要查看时由用户主动打开；自动流程不启动报告网页。

## 验收边界

- 截图和规则检查不能证明与原版主观手感完全一致，仍保留人工体验验收。
- Chromium 运行真实 WebGL，但采用软件渲染；Web 自动化模式将 3D 分辨率降至 50%、关闭阴影/MSAA、逻辑主循环限制 20 FPS、战斗画面每秒提交两次，物理仍为 60 Hz、玩法数值不变。窗口尺寸为 960×600，不代表玩家显卡帧率、高画质效果或流畅度验收。
- Windows EXE 验证的是成品内资源、主场景、逻辑与输入路径；不启动 Windows 图形窗口，因此不声称验证了原生 GPU 显示效果。
- ENet 测试不代表双账号 Steam 房间/P2P 验收；Steam 登录与跨电脑联网仍需专门环境。
- 推送门禁由本地工具与工作约定执行；Actions 验证失败会阻止本次下载包产生。仓库分支保护并未由此自动开启。
