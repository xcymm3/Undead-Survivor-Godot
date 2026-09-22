# 地图与模式

## 保卫水晶（`graypine_defense`）

默认入口为十波水晶防守。僵尸从断崖对岸刷新，依次穿过吊桥、爬上带挡土结构与排水边沟的缓坡，并进入水晶前的开阔高地。地图保留中央长射界，在道路两侧布置可碰撞岩石作为有限掩体；除吊桥两侧的开放断崖外，其他外边界均由连续石墙封闭。草地、土层、道路、岩壁、木桥和石墙使用不同的程序化风化表面。玩家进入后可在水晶后方的绿色安全区查看完整武器墙，并用 `1—0` 更换主武器；只有在水晶旁按 `E` 拉下拉杆后，计时和第一波刷新才会开始。

每个僵尸持续比较玩家和水晶的距离，攻击最近的有效目标。波次越高，敌人种类、数量、生命和伤害越强。水晶拥有固定 1500 点耐久，波间不恢复；水晶被摧毁或全队失去行动能力时失败，清除第十波时胜利。

场景入口为 `scenes/graypine_defense.tscn`，布局与高度见 `scripts/defense_layout.gd`，程序化场景见 `scripts/defense_world.gd`，权威规则位于 `scripts/simulation.gd`。`tools/validate-defense.gd` 无窗口验证地图物理、拉杆门禁、安全区换装、最近目标选择、强度成长及胜负条件。

## 灰松夜路（`graypine_night`）

原紧凑战役继续保留，可从首页切换。场景入口为 `scenes/graypine_night.tscn`；布局与碰撞见 `scripts/night_layout.gd`、`scripts/night_world.gd`，导演见 `scripts/night_director.gd`。

日常 `npm run verify` 只执行基础检查；修改本地图时可运行 `./tools/validate-headless.ps1 -Mode Defense`。用户明确要求全量验收或准备打包 EXE 时，才由全量流程运行水晶防守专项、夜路整关、ENet、Web 与浏览器检查。水晶防守的多人整关、原生 GPU 和真人节奏仍需单独验收。
