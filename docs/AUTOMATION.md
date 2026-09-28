# 自动测试与打包

## 日常开发

日常修改默认只运行：

```powershell
npm run verify
```

基础检查包含版本一致性、Godot 资源导入、原生组件断言和僵尸优化状态专项。根据改动范围，可额外运行一个专项：

```powershell
./tools/validate-headless.ps1 -Mode Defense
./tools/validate-headless.ps1 -Mode DefenseSpawns
./tools/validate-headless.ps1 -Mode SpreadBallistics
```

提交前执行 `node tools/automation.mjs --check-report`，确认报告与当前源码摘要一致。基础检查通过只说明所列快速项目通过，不代表整关、联网、浏览器、视觉或发布验收通过。

## 发布技术门禁

只有用户明确要求验收或全量测试时运行：

```powershell
npm run verify:full
```

发布技术门禁在基础检查之外运行保卫水晶规则专项、弹道、Web 导出，以及七组浏览器技术检查（包含建筑交互和僵尸角色碰撞专项）。它验证确定性的规则、主页、装备、输入安全与构建能力，不把脚本操控角色通关或联机结果作为游戏品质结论。

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

## 僵尸碰撞与导航专项

先执行 `./tools/validate-headless.ps1 -Mode ExportWeb`，然后执行 `npx playwright test tests/browser/enemy-physics.spec.mjs tests/browser/defense-structures.spec.mjs`。浏览器为 headless Chromium，禁止锁定鼠标和全屏请求。碰撞专项通过正常房主物理循环检查普通、巨人、小鬼、爬行僵尸对建筑、水晶和玩家的攻击（巨人、小鬼沿用不攻击玩家的规则），死亡即时取消碰撞、五个刷新点的桥口路径，以及 50／100／200 只混合敌人的拥堵、后排前进尝试和每个物理 tick 的角色碰撞移动耗时。

拥堵用例持续 20 个游戏秒，其中前 2 秒不计入性能统计；为持续观察完整栅栏门，该用例将门耐久提高并关闭炮塔火力。默认 1000 血量门的正常破坏与通行由建筑专项单独验证。性能数字是 Web 运行环境中的原生碰撞调用墙钟时间，包含 sweep、滑动、碰撞查询与同步代理，不包含导航缓存构建、渲染、完整游戏帧或原生 Windows GPU 性能。结果保存于忽略提交的 `artifacts/enemy-physics-*.json`。

原生引擎对照使用 `./tools/validate-headless.ps1 -Mode EnemyPhysics -TimeoutSeconds 600`，执行相同体型、数量、20 秒场景与 2 秒预热，输出 `artifacts/enemy-physics-native.json`。此模式不启动图形窗口，也不导出 EXE；通过独立的角色扫掠调用测量碰撞开销，不包含原生 GPU 渲染或整帧性能。


优化专项可独立执行 `./tools/validate-headless.ps1 -Mode EnemyOptimization`。碰撞压力报告同时记录移动调用耗时与完整房主 `simulation.step` 耗时（含索敌、导航、状态处理、同步、碰撞及建筑逻辑），并记录共享路线命中和拥堵提前唤醒次数。二者均不含渲染和引擎独立物理步；不得把碰撞移动耗时当作整帧耗时。前后对比应使用相同布置、数量、20 秒观察与 2 秒预热，并串行执行性能测试，避免相互抢占 CPU。

需要减少前后测试时段差异时，先准备独立的旧版本 Godot 工作区，再执行 `./tools/benchmark-enemy-physics-paired.ps1 -BaselineProjectPath <旧版本目录>`。脚本将相同测试脚本复制到旧版本的忽略目录，按 50、100、200 只逐组串行运行旧版本和当前版本；输出 `artifacts/enemy-physics-paired.json`。它只运行真正 headless 的引擎，不修改旧版本玩法源码，不启动图形进程；旧版本必须支持原有僵尸碰撞测试接口。
