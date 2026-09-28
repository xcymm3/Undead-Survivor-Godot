# Godot 工程说明

本仓库是从旧项目移植并继续开发的独立 Godot 4.5.2 工程，运行时不依赖 React、Three.js、Electron 或相邻源码目录。Steam 使用与 Godot 4.5 匹配的 GodotSteam 4.16 模板。

## 当前范围

- 工程只保留 `graypine_defense`：保卫水晶，包含吊桥、缓坡、开阔平台与八波防守；每波由全员按 T 开始。
- 单人和房主共用 `scripts/simulation.gd`；客户端只发送输入，位置、生命、命中与胜负由房主决定。
- 地形、碰撞、寻路、敌人 CPU 命中姿态和 GPU 显示共享同一组原生规则。
- 十种武器、八类敌人、补给、推击、医疗、投掷物和本地/Steam 合作沿用当前源码定义。

## 主要模块

| 范围 | 实现 |
| --- | --- |
| 入口与地图目录 | `scripts/main.gd`、`scripts/map_catalog.gd` |
| 玩法与房主权威 | `scripts/simulation.gd` |
| 水晶防守 | `scenes/graypine_defense.tscn`、`scripts/defense_world.gd` |
| 一次性炮塔、地雷与栅栏门 | `scripts/defense_structures.gd`、`scripts/defense_structure_view.gd` |
| 共享装备与场景几何 | `scripts/equipment_core.gd`、`scripts/equipment_props.gd`、`scripts/world_geometry.gd` |
| 敌人积分分配 | `scripts/enemy_population.gd`、`scripts/defense_population.gd` |
| 网络会话 | `scripts/session.gd` |
| HUD 与菜单 | `scripts/interface.gd` |
| 数据与武器规则 | `scripts/data.gd`、`assets/data/rules.json` |

## 验证边界

日常修改按 [自动测试与打包](AUTOMATION.md) 运行基础检查和相关专项。只有用户明确提出本地验收/全量测试时，才在本机运行全量流程；正式 EXE 发布的全量验收与打包交给 GitHub Actions。

自动检查不代表原生 GPU 画质、真人难度与趣味性、实际音效听感或 Steam 双账号跨网络体验已经通过。需要截图或视觉验收时，按 [视觉检查](VISUAL_QA.md) 单独执行并记录观察结果。

新增建筑专项 `tools/validate-defense-structures.gd` 覆盖炮塔躯干瞄准和步枪火力、射程与遮挡、九种敌人攻击建筑、栅栏门的原生玩家碰撞与跳跃、地雷复用手雷伤害和引信、波间持久状态及客户端快照。建筑改变阻挡和索敌规则，网络协议升级为 `undead-survivor-godot-16`，旧客户端不能混用。静态 Web 截图使用临时源码副本和 headless Chromium / SwiftShader，不启动桌面 Godot 图形进程。

炮塔位于缓坡出口左右的顶部平地（x=±6.3、z=-6、地面高 3 米），不占用斜坡；炮塔和栅栏门不显示头顶名称或血量。栅栏门移至缓坡顶部（z=-10、地面高 3 米），宽度 10.4 米覆盖整个坡口，使用金属钢条、横梁和铆钉。`tests/browser/defense-structures.spec.mjs` 在独立 headless Chromium 中布置敌人后，使用正常游戏物理循环观察绕门、攻击建筑、炮塔击杀与残骸、地雷首次爆炸及再次接触，以及九类僵尸在门外左、中、右攻击位置的炮塔支援射击；没有通过直接扣血来替代战斗。该专项不代表整关试玩或 Steam 双账号验证。

提交遵循简体中文 Conventional Commits。远程仓库已配置时，只提交本次相关文件并推送当前分支，不包含用户已有的无关改动。
