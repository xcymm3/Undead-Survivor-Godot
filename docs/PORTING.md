# Godot 工程说明

本仓库是从旧项目移植并继续开发的独立 Godot 4.5.2 工程，运行时不依赖 React、Three.js、Electron 或相邻源码目录。Steam 使用与 Godot 4.5 匹配的 GodotSteam 4.16 模板。

## 当前范围

- `graypine_night`：灰松夜路战役，支持单人和合作模式。
- `graypine_defense`：保卫水晶，包含吊桥、缓坡、开阔平台、拉杆开战与十波防守。
- 单人和房主共用 `scripts/simulation.gd`；客户端只发送输入，位置、生命、命中与胜负由房主决定。
- 地形、碰撞、寻路、敌人 CPU 命中姿态和 GPU 显示共享同一组原生规则。
- 十种武器、八类敌人、补给、推击、医疗、投掷物和本地/Steam 合作沿用当前源码定义。

## 主要模块

| 范围 | 实现 |
| --- | --- |
| 入口与地图目录 | `scripts/main.gd`、`scripts/map_catalog.gd` |
| 玩法与房主权威 | `scripts/simulation.gd` |
| 夜路地图 | `scenes/graypine_night.tscn` 与夜路脚本 |
| 水晶防守 | `scenes/graypine_defense.tscn`、`scripts/defense_world.gd` |
| 网络会话 | `scripts/session.gd` |
| HUD 与菜单 | `scripts/interface.gd` |
| 数据与武器规则 | `scripts/data.gd`、`assets/data/rules.json` |

## 验证边界

日常修改按 [自动测试与打包](AUTOMATION.md) 运行基础检查和相关专项。只有用户明确提出验收/全量测试，或准备打包 EXE 时，才运行全量流程。

自动检查不代表原生 GPU 画质、真人难度与趣味性、实际音效听感或 Steam 双账号跨网络体验已经通过。需要截图或视觉验收时，按 [视觉检查](VISUAL_QA.md) 单独执行并记录观察结果。

提交遵循简体中文 Conventional Commits。远程仓库已配置时，只提交本次相关文件并推送当前分支，不包含用户已有的无关改动。
