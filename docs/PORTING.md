# Godot 工程说明

本仓库是从旧项目移植并继续开发的独立 Godot 4.5.2 工程，运行时不依赖 React、Three.js、Electron 或相邻源码目录。Steam 使用与 Godot 4.5 匹配的 GodotSteam 4.16 模板。

## 当前范围

- 工程只保留 `graypine_defense`：保卫水晶，包含吊桥、缓坡、开阔平台与无尽防守；每波由全员重新按 T 开始。预算曲线前移三波：基础预算138，后续增量按 `max(5, round(31 × 0.92^(波次+1)))` 计算，第20波起每波增加5分。普通与爬行每只0.75分，特殊最多使用25%预算，不足一只普通僵尸的尾数不超额消费。刷新按本波总人数安排30秒批次，数量多时增加频率或批量。橄榄球第6、7波各按人数投放，第8波起每波按人数的两倍投放。
- 单人和房主共用 `scripts/simulation.gd`；客户端只发送输入，位置、生命、命中与胜负由房主决定。
- 跳跃保留世界坐标水平速度，空中输入按方向投影限速逐步加速：加速度 4 米/秒²、输入方向速度上限 1.5 米/秒、总水平速度上限 4.2 米/秒。松键和转动视角保留惯性，反向键逐步减速；空中蹲下不缩放已有速度，墙体碰撞移除受阻速度，落地恢复地面移动。该规则借鉴 Source 空中加速思路，参数适配本游戏，不宣称完全复刻 CS:GO。
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

武器外观统一由 `scripts/weapon_models.gd` 创建，第一人称、墙上展示、队友持枪与领取/丢弃动画使用相同枪身、材质和瞄具。左轮的共享模型与机械动作位于 `scripts/revolver_model.gd`，第一人称晃动和换弹取消恢复单独由 `scripts/revolver_view.gd` 控制；世界模型使用正常渲染层和阴影，第一人称实例才切换至专用层并关闭阴影。

## 验证边界

日常修改按 [自动测试与打包](AUTOMATION.md) 运行基础检查和相关专项。只有用户明确提出本地验收/全量测试时，才在本机运行全量流程；正式 EXE 发布的全量验收与打包交给 GitHub Actions。

自动检查不代表原生 GPU 画质、真人难度与趣味性、实际音效听感或 Steam 双账号跨网络体验已经通过。需要截图或视觉验收时，按 [视觉检查](VISUAL_QA.md) 单独执行并记录观察结果。

新增建筑专项 `tools/validate-defense-structures.gd` 覆盖炮塔躯干瞄准和火力（当前伤害为步枪的一半，即 60，间隔 0.12 秒）、射程与遮挡、九种敌人攻击建筑、栅栏门的原生玩家碰撞与跳跃、地雷复用手雷伤害和引信、波间持久状态及客户端快照。装备改为双武器独立弹药、固定斧和每波三枚手雷，移除医疗包；装备与预算机制改变玩法，网络协议现为 `undead-survivor-godot-21`，旧客户端不能混用。静态 Web 截图使用临时源码副本和 headless Chromium / SwiftShader，不启动桌面 Godot 图形进程。

炮塔位于缓坡出口左右的顶部平地（x=±6.3、z=-6、地面高 3 米），不占用斜坡；炮塔和栅栏门不显示头顶名称或血量。栅栏门移至缓坡顶部（z=-10、地面高 3 米），宽度 10.4 米覆盖整个坡口，使用金属钢条、横梁和铆钉。`tests/browser/defense-structures.spec.mjs` 在独立 headless Chromium 中布置敌人后，使用正常游戏物理循环观察绕门、攻击建筑、炮塔击杀与残骸、地雷首次爆炸及再次接触，以及九类僵尸在门外左、中、右攻击位置的炮塔支援射击；没有通过直接扣血来替代战斗。该专项不代表整关试玩或 Steam 双账号验证。

提交遵循简体中文 Conventional Commits。远程仓库已配置时，只提交本次相关文件并推送当前分支，不包含用户已有的无关改动。

## 敌人二维移动

按用户要求撤回 `b0c401a` 与 `dfaf975` 的敌人实体碰撞、按体型导航、物理批量管理和拥堵唤醒实现。敌人主要保存二维 `pos`，用线段与障碍矩形检查移动并沿坐标轴滑动，共用旧版 AStarGrid2D；邻居分离只影响避让方向，允许活僵尸重叠。推搡、受击位移、攻击前移和冲锋也恢复旧版位置计算；僵尸不再作为近战遮挡物。玩家仍使用原生物理与旧版距离阻挡，波次刷新仍保留出生点间距策略。

保留后续无尽波次、30 秒动态分批刷新、炮塔伤害、双武器槽与跳跃惯性。敌人显示与 CPU 命中重新从共享地形计算高度，网络协议为 `undead-survivor-godot-21`。原有 [CPU 测量报告](CPU_PROFILE_2026-09-29.md) 是回退前实现的历史数据，不能代表当前性能；测量工具已适配二维移动，GPU 仍需隔离环境单独测量。
