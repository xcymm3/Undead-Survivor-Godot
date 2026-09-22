# 自动测试与打包

## 日常开发

日常修改默认只运行：

```powershell
npm run verify
```

基础检查包含版本一致性、Godot 资源导入和原生组件断言。根据改动范围，可额外运行一个专项：

```powershell
./tools/validate-headless.ps1 -Mode Defense
./tools/validate-headless.ps1 -Mode Night
./tools/validate-headless.ps1 -Mode SpreadBallistics
```

提交前执行 `node tools/automation.mjs --check-report`，确认报告与当前源码摘要一致。基础检查通过只说明所列快速项目通过，不代表整关、联网、浏览器、视觉或发布验收通过。

## 全量测试

只有用户明确要求验收或全量测试时运行：

```powershell
npm run verify:full
```

全量测试在基础检查之外运行灰松夜路整关、保卫水晶专项、弹道、ENet 双人、Web 导出，以及保留的浏览器真实输入与地图斜俯视检查。水晶防线单人自动试玩会记录胜负、波次、血量和命中结果至报告的“玩法观察”；试玩胜负不阻塞全量检查，页面异常、路线越界和输入安全断言仍会失败。

## Windows EXE

准备导出或打包 EXE 时运行：

```powershell
npm run verify:release
```

发布命令会自动先执行全量技术测试，再进行 Windows 导出、成品 EXE 无窗口冒烟、单文件隔离检查和 ZIP 打包，不需要额外的 release-full 命令。水晶防线单人自动试玩结果写入“玩法观察”，不作为打包门禁。GitHub Actions 也使用这条路径。

所有本机检查必须保持无窗口，不捕获鼠标、不切换全屏、不操作用户已有的 Godot 或浏览器窗口。日志与报告写入忽略版本控制的 `artifacts/`；单项 PowerShell 检查只在失败时于根目录保留诊断日志。
