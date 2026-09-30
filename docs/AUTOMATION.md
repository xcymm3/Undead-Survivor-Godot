# 自动测试与打包

## 日常开发

日常修改默认只运行：

```powershell
npm run verify
```

基础检查包含版本一致性、Godot 资源导入、原生组件断言和增量进度/存档专项。根据改动范围，可额外运行一个专项：

```powershell
./tools/validate-headless.ps1 -Mode Defense
./tools/validate-headless.ps1 -Mode Progression
./tools/validate-headless.ps1 -Mode DefenseSpawns
./tools/validate-headless.ps1 -Mode DefenseWaves -TimeoutSeconds 600
./tools/validate-headless.ps1 -Mode SpreadBallistics
```

提交前执行 `node tools/automation.mjs --check-report`，确认报告与当前源码摘要一致。基础检查通过只说明所列快速项目通过，不代表整关、联网、浏览器、视觉或发布验收通过。

## 发布技术门禁

只有用户明确要求验收或全量测试时运行：

```powershell
npm run verify:full
```

发布技术门禁在基础检查之外运行保卫水晶规则专项、弹道、Web 导出，以及六组浏览器技术检查（包含建筑交互专项）。它验证确定性的规则、主页、装备、输入安全与构建能力，不把脚本操控角色通关或联机结果作为游戏品质结论。

## 独立试玩观察

```powershell
npm run verify:playtests
```

这项命令单独运行水晶防线浏览器脚本试玩，并写入 `artifacts/playtests.json` 与 `artifacts/playtests.md`。这些结果用于发现风险和辅助真人试玩，不被 `verify:full`、`verify:release` 或 GitHub 发布工作流调用；无论通过或失败，都不改变正式发布门禁结论。

## Windows EXE

正式 EXE 发布先在本地运行基础检查与相关专项，提交并推送源码。以下命令由 GitHub Actions 对同一提交执行；只有用户明确要求本地生成 EXE 或本地发布验收时才在本机运行：

```powershell
npm run verify:release
```

发布命令会自动先执行发布技术门禁，再进行 Windows 导出、成品 EXE 无窗口冒烟、单文件隔离检查和 ZIP 打包，不需要额外的 release-full 命令。GitHub Actions 也只使用这条路径，不执行独立试玩或联机观察。

所有本机检查必须保持无窗口，不捕获鼠标、不切换全屏、不操作用户已有的 Godot 或浏览器窗口。日志与报告写入忽略版本控制的 `artifacts/`；单项 PowerShell 检查只在失败时于根目录保留诊断日志。

`DefenseWaves` 验证0.75分普通成本、特殊预算从25%升至50%、总预算下调至85%、人数/难度缩放、动态30秒批次及刷新点堵塞后的保留配额。它使用正常房主物理循环模拟普通单人第一波，输出 `artifacts/first-wave-horde.json` 的实际种类、出生时间和位置；不是浏览器或整波生存试玩。
