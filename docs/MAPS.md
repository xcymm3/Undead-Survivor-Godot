# 地图选择与沙漠之城

首页可以选择原有地图或“沙漠之城”，选择会保存在本机设置。单人模式使用当前选择；合作房间由房主选择地图，客户端跟随房主加载。所有队员完成加载后才开始对局，加载期间离开或超时会结束房间并提示重建。

沙漠之城参考第一代 **de_dust**，不是 Dust II。布局依据原作者 Dave Johnston 的[设计回顾](https://www.johnsto.co.uk/design/making-dust/)与其中的俯视图，包含 T 区长庭院、侧面通道、中央地下通道、A 区高台和 B/CT 庭院。使用 Godot 原生网格、静态碰撞、灯光与程序化砂岩材质重建；没有导入 CS 的 BSP 或原版美术资源，也未验证尺寸或视觉效果与原版完全一致。

## 开发入口

- `scripts/map_catalog.gd`：地图名称、场景、边界、出生点、刷怪点、菜单镜头与环境颜色。
- `scripts/dust_layout.gd`：地图区域、地形高度与箱体布局。物理地面和游戏地形查询共用高度函数。
- `tools/dust_builder.gd`：离线构建原生场景；运行 `powershell -File tools/validate-headless.ps1 -Mode BakeDust` 后保存到 `scenes/dust.tscn`。
- `scripts/arena.gd`：按地图生成寻路网格、阻挡区域和坡度限制。沙漠不启用原地图河流与涉水规则。

## 定向验证

运行 `powershell -File tools/validate-headless.ps1 -Mode Maps` 检查首页切换、出生点、寻路连通、坡地落地、墙体碰撞、刷怪和合作地图协议。`-Mode NativeComponents` 检查原生组件回归。

联网检查可分别启动 `-Mode NetworkHost -Map dust -ExpectMap dust` 和 `-Mode NetworkClient -Map outpost -ExpectMap dust`，验证客户端跟随房主选择以及移动、跳跃、落地、射击和房主权威。此检查仅覆盖本机 ENet 双进程，不代表 Steam 双账号验收。

`npm run verify` 包含上述原生检查、两张地图的 ENet 双人/四人检查和真实浏览器输入验收。实际结果与源码 SHA-256 记录在 `artifacts/acceptance.md`；只有与当前源码匹配的全绿报告才能通过提交门禁。首页截图已按用户要求生成，不代表沙漠地图的完整视觉验收。
