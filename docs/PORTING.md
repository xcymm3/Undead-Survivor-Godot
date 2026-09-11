# 移植说明

## 基线与范围

- 玩家移动改用 `CharacterBody3D` 与半径 0.3 米、高 1.8 米的胶囊体，复用 `arena.gd` 从场景网格构建的原生静态三角面碰撞。`player_body.gd` 使用 `move_and_collide` 的扫掠结果和碰撞法线处理滑动、落地、斜坡与撞顶；显式传入位移以支持共享模拟的小步长，不依赖渲染帧时间。重力仍由角色脚本施加（18 米/秒²），起跳速度仍为 8.4 米/秒。
- `height` 现在表示脚底的真实世界高度，`grounded` 表示胶囊体检测到地面；站在高台上可以再次起跳，角色姿态和浏览器验收使用 `grounded`，不再假设落地高度必须为零。空中输入仍采用起跳时的移动量，视角转动仍影响水平方向。
- 单人/合作房主创建并驱动玩家物理节点，客户端只同步位置、高度、落地状态。节点在玩家离开、退出、重开和模拟器销毁时释放。僵尸仍采用共享二维地形寻路与原有接触规则；角色胶囊体沿真实场景轮廓碰撞，敌人路径继续使用保守膨胀边界。击退也执行原生胶囊扫掠，河流继续使用共享河岸/桥梁数据判定落水。
- 无窗口回归覆盖真实桥面通行、落水复位、跳跃高度、空中禁止二段跳、高台落地与起跳、低天花板、墙面滑动、斜坡、击退阻挡及物理节点生命周期；ENet 2/4 人验证同时检查跳跃、落地快照和房主物理节点归属，不等同于 Steam 双账号验证。

- 橄榄球僵尸不再限制同时存活数量，按波次队列顺序和既有刷新速率生成，仍遵守安全出生点检查。

- 本地玩法调整：橄榄球僵尸在 0.35 秒蓄力结束时锁定方向，冲刺最长 4 秒；撞击造成 30 点伤害并沿冲刺方向击退最多 0.65 米（受地形、边界与敌人阻挡），保留受伤保护和跳跃闪避；撞墙眩晕 2 秒，扑空仍恢复 0.45 秒。由单人/合作房主共享模拟执行。

- 来源目录：`../Undead-Survivor`。
- 来源提交：`7775293140052ccf9f86ea86929bfbc8889a4a5b`，版本 0.7.7。
- 目标：Godot 4.5.2 Compatibility / GDScript；Steam 使用 GodotSteam 4.16 的 Godot 4.5 编译版。
- 原项目未修改；运行时不加载 WebView、不执行 JavaScript、不启动 Electron。

## 模块对应

| 原模块 | Godot 实现 | 迁移方式 |
| --- | --- | --- |
| `world.ts`、`terrainView.ts`、`geometry.ts` | `arena.gd`、`world.json` | 执行原几何构建函数，提取顶点、法线、索引、实例变换和碰撞占地；原生 ArrayMesh / MultiMesh 重建 |
| `terrain.ts`、`navigation.ts`、`player.ts` | `data.gd`、`arena.gd`、`simulation.gd` | 同一折线河道、桥梁、0.95 米导航膨胀；AStarGrid2D 路径、连续矩形线段检查、空间分区 |
| `config.ts`、`weapons.ts`、`enemyRoster.ts` | `rules.json`、`data.gd`、`simulation.gd` | 原数值提取、阶位池与刷新公式移植 |
| `firearm.ts`、`arsenal.ts` | `simulation.gd` | 弹匣、射速、装填、逐发装填、动作完成后切换 |
| `weapon.ts` | `convert-assets.mjs`、`weapon_view.gd` | 原 FBX 色板、轴向和骨骼修正；十款武器动作按 30 Hz 采样并导出 GLB |
| `sights.ts`、`SightOverlay.tsx` | `main.gd`、`interface.gd` | 真正的投影倍率、缩放灵敏度、原生瞄准镜绘制 |
| `zombies.ts` | `enemy_view.gd`、`enemy_animation.gdshader` | 43 个原始部件；8 个共享实例批次，GPU 驱动腿、手臂和盾牌动作；命中使用相同逐部件 CPU 变换 |
| `encounter.ts`、`movement.ts`、`spawn.ts` | `simulation.gd` | 正式/练习、攻击状态、精英技能、安全刷新、波次恢复 |
| `ballistics.ts`、`Game.ts` 攻击部分 | `data.gd`、`simulation.gd` | 确定性扇面散布、屏幕中心目标、枪口遮挡、逐部件命中、穿透/近战去重、按开火次数计命中 |
| `soundSynthesis.ts`、`audio.ts` | WAV、`sound.gd` | 原音乐、护甲和死亡采样保留；WebAudio 枪声/机械声等转为本地近似合成 |
| `blood.ts`、`armorEffects.ts` | `effects.gd` | 有上限的实例化血粒、护甲碎片和火焰 |
| `App.tsx`、`home.css`、菜单组件 | `interface.gd` | 原生 Control；主菜单采用当前源码的场景背景、左下标题、右侧模式列表；纸色设置与深色 HUD |
| `graphics.ts` | `data.gd`、`pixelation.gdshader` | 五档预设、单项设置和持久化；抗锯齿替换为 Godot MSAA |
| `leaderboard.ts` | `data.gd` | 本机前十，波次/击杀/时长排序，独立原生存档 |
| `CoopSession.ts`、`PartnerView.ts`、Steam bridge | `session.gd`、`partner_view.gd` | GodotSteam P2P / ENet；同一房主权威模拟、随机角色和配色、死亡观战、清波复活 |

## 运行约束

- 无法使用的刷怪入口不会减少配额，不累计突发补刷。
- 僵尸移动和冲锋均检查河道；冲锋蓄力时锁定方向。
- 每名玩家的存活状态、位置、弹匣与击杀只由房主更新；客户端字段经过白名单、类型、数值和序号检查。
- Steam 的大快照使用可靠 P2P，避免超过不可靠包 1200 字节限制；结束快照可靠发送。
- 仅从房主接受世界状态；仅从房间成员接受操作；解包不允许对象反序列化，限制包体和处理数量。
- 菜单与单人暂停按需绘制，失焦停止绘制；多人后台仍按固定物理步长模拟。
- 尸群没有逐个僵尸 Node 树、物理刚体或独立材质。八类共享批次是原单批次在 Godot 中的适配。

## 验证与未验证项

标准 Godot 4.5.2 与 GodotSteam / Godot 4.5 均完成导入和 148 项无窗口运行检查，零失败。十款枪械、八类敌人和队友模型已完成实际 GPU 取图。双客户端和四客户端真实 ENet 进程之间的建房、加入、开始、输入、移动、射击和世界同步均已通过；最终四人回归的三个客户端各收到 89～90 次快照，全部进程退出无错误或警告。

256 只僵尸的单机脚本分析已用于定位并修正逐个邻居查找与每帧逐部件 CPU 动画的性能瓶颈。实例更新移入 GPU 后，检查机上 256 只的 CPU 实例提交中位耗时约 2.9 ms；这只是脚本测量，不代表完整游戏 FPS，也不代表所有显卡的性能。

以下不作已通过声明：

- 两个独立 Steam 账号、不同电脑/网络的完整联网验收。GodotSteam 引擎与具体方法/信号已核对，房间及 P2P 实现已接入。
- 原生 Windows 图形窗口和跨电脑 Steam 完整运行体验。新增自动化流程会验证导出后的 EXE（无窗口模式），具体运行结果以 `artifacts/acceptance.json` 和 GitHub Actions 为准。
- 与原版逐像素一致。原几何和姿态保留，渲染器、阴影、字体栅格化、音频引擎和粒子表现有所不同。
- 原浏览器/Electron 的排行榜自动迁入。Godot 有独立存档，原存档保持原状。
- 原 Electron 与 Godot 客户端互联；两者协议和传输实现不同，应让全部队友使用同一 Godot 版本。

## 后续开发

修改 `assets/data/rules.json` 可调平衡；修改原项目后重新运行 `tools/convert-assets.mjs` 会覆盖该文件与生成资源。修改玩法请集中在 `simulation.gd`，保证单人与房主使用同一套规则。修改 GPU 僵尸动作时同步调整 `enemy_view.gd` 的 CPU 逐部件变换，保证视觉与命中一致。

工程关联独立远程仓库 `https://github.com/xcymm3/Undead-Survivor-Godot`。提交前执行完整自动验收与源码摘要门禁，使用简体中文 Conventional Commits 主题，不强制推送。流程与验收边界见 [AUTOMATION.md](AUTOMATION.md)。
