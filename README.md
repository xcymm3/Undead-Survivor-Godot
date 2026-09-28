# Undead Survivor · Godot

当前源码仅保留**水晶防线**：穿过吊桥的八波尸潮会攻击玩家或水晶。首页可直接选择难度，进入单人防守或合作模式，无需选择地图。

[下载 Windows 单文件 EXE](https://github.com/xcymm3/Undead-Survivor-Godot/releases/latest)。已发布版本可能早于当前分支；游戏与 Steam 依赖内置，无需另下 DLL。

## 玩法与操作

保护拥有 1500 耐久的水晶，清除第八波即获胜。僵尸随机从对岸五处位置刷新，穿过吊桥和缓坡。每波开始前按 T；合作模式需要所有队员重新按 T 准备。水晶不在波间恢复。

| 操作 | 按键 |
| --- | --- |
| 移动 / 转向 | WASD / 鼠标 |
| 跳跃 / 蹲下 | 空格 / Ctrl |
| 攻击 / 推搡 / 切换开镜 | 左键 / 右键 / 中键 |
| 换弹 | R，空仓有备弹时自动换弹 |
| 主武器 / 副武器 / 消防斧 | 1 / 2 / 3 |
| 手雷 / 医疗包 | 4 / 5 |
| 军械库换枪与拾取补给 | E |
| 开始本波 / 准备下一波 | T |
| 暂停 / 静音 / 全屏 | Esc / M / F11 |

后方军械库无限供应枪械、手雷和医疗包；主武器仍有有限备弹并需要换弹。最多携带三枚手雷和一个医疗包。手雷为 1.5 秒引信，不伤害自己或队友；医疗包治疗三秒后恢复至 100 生命，右键可治疗附近队友。推搡保留换弹进度，第三次连续推搡后冷却 3.5 秒。开波前可以射击与推搡。

## 合作

支持 Steam 房间和原生 ENet 局域网直连，最多四人。房主决定位置、生命、命中与胜负，客户端只发送输入；房主退出则对局结束。所有队员必须使用同一协议版本。

Steam 合作需登录 Steam，开发 App ID 为 480。局域网地址为房主 IP:27777。Godot 版不能与原 Electron 版混合联机。Steam 双账号跨网络体验需实际验证。

## 开发与验证

本项目是独立 Godot 4.5.2 原生工程，运行时不依赖相邻项目、React、Three.js 或浏览器。

- `npm run verify`：版本、无窗口资源导入和原生组件基础检查。
- `./tools/validate-headless.ps1 -Mode Defense`：水晶规则专项。
- `./tools/validate-headless.ps1 -Mode DefenseSpawns`：五个刷怪点与桥口路线专项。
- `npm run verify:full`：用户明确要求时运行全量技术检查。
- 正式 EXE 发布由 GitHub Actions 执行 `npm run verify:release`，完成全量技术门禁、导出、成品无窗口冒烟和打包。

本机自动检查必须真正 headless，不打开游戏窗口或干扰桌面。基础通过不等于全量、视觉、实际音效或真人体验验收通过。

设计与验证细节：[地图](docs/MAPS.md)、[战斗与补给](docs/COMBAT_REVISION.md)、[近身战斗](docs/CLOSE_COMBAT.md)、[自动化](docs/AUTOMATION.md)、[按需视觉检查](docs/VISUAL_QA.md)。

## 资源与许可

六款枪械及人物资源来自 Quaternius CC0 素材；地图、僵尸、程序化武器和合成音频来自原项目及本工程。许可见 `assets/THIRD-PARTY-NOTICES.txt`、`assets/models/WEAPON-SOURCES.md` 和人物目录许可。资源转换工具仅用于开发，不修改相邻项目。
