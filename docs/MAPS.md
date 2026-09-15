# 灰松夜路

游戏仅保留灰松夜路（`graypine_night`）。旧存档中的地图选择自动回到夜路，菜单和房间不再提供地图切换，联机校验拒绝旧地图编号。

场景入口为 `scenes/graypine_night.tscn`；布局与碰撞见 `scripts/night_layout.gd`、`scripts/night_world.gd`，导演见 `scripts/night_director.gd`。

`npm run verify` 仅检验夜路单人、双人，包括内部输入整关、真实 ENet 双人、装备与移动规则、浏览器输入和软件截图。不再检验其他地图或三/四人，现有房间人数上限未改变。历史设计文档保留用于追溯。
