# 40秒宣传片（2026-10-23）

按本次确认方案重拍最新源码，输出 artifacts/trailer40/Undead-Survivor-Trailer-40s-1080p.mp4。保留原60秒工程及成片。

0–6秒步枪与手雷；6–13秒包围、弹药耗尽与原生长刀大招；13–18秒水晶防线；18–24秒舞王跳舞与召唤；24–28秒真实商店购买；28–32秒炮塔、栅栏与地雷；32–37秒四名角色协同射击、远近镜头；37–40秒四人战斗定格，无字幕和标题。

只添加五句宣传字幕：迎击海量尸潮、守住最后防线、升级永久保留、筑起你的防线、并肩迎战。每句只短暂显示。升级镜头保留游戏内原生商品交互提示，其他镜头隐藏HUD和角色姓名。没有消防斧镜头，也没有标题卡。

用户已明确授权本次全程无窗口拍摄。Godot只用于 --headless 导入及Web导出；在隔离源码副本中用 headless Chromium + SwiftShader逐帧渲染。音频静音拍摄后按事件重建，不操作桌面。Windows编码和验证子进程使用CREATE_NO_WINDOW。生产游戏源码不引用拍摄脚本。

镜头编排包括敌人位置、推进速度、保护角色、场景灯光、初始装备及四名权威模拟角色。四人画面使用实际玩家控制器、队友模型和原生战斗；不属于四客户端联机/Steam测试。长刀、伤害、召唤、爆炸、商店购买和防御建筑均调用项目当前实现。软件Web透明第一人称合成中的残影出现深色遮挡，因此仅拍摄时关闭残影层，保留原生挥刀轨迹、刀身与流转蓝芒；生产游戏不变。素材来源及镜头脚本摘要记录在source.json。

复现（根目录执行）：

```powershell
node tools/trailer/capture40.mjs --prepare --preview
node tools/trailer/capture40.mjs --prepare --capture
python tools/trailer/edit40.py
python tools/trailer/edit40.py --verify
```

后期依赖共用 requirements.txt 和 edit.py 的字体、音频合成工具。原始素材、事件记录、成片、封面、联系表、技术报告均保存在忽略目录artifacts/trailer40。完整解码、40秒/1080p/24FPS、音频峰值、五句字幕清单、四人及大招/购买记录和结尾静帧由edit40.py检查；图像仍须实际打开审查，检查记录见该目录review.md。软件Web画面不代替原生GPU、真人体验或发布验收。
