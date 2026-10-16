# CC0 战斗音效来源与选择记录

本次接入54个音频条目；输入节选、上游文件SHA-256、裁切范围与处理配方均保存在仓库。所有条目均来自已存在的CC0素材，处理包括裁切、声道转换、去直流、滤波、淡入淡出、重采样与录音分层，不使用振荡器或噪声重新合成。

**验证边界：**已核对作者说明、许可证、文件内容参数、运行时路由与动作时钟；没有在用户桌面播放音频，也未进行真人游戏内试听。下面的选择理由依据素材描述、录音类型和动作匹配，不等同于主观听感已验收。

## 来源包

| ID | 作者与来源 | 选择依据 |
| --- | --- | --- |
| `zombies` | artisticdude · [原始页面](https://opengameart.org/content/zombies-sound-pack) | 同一游戏用途的僵尸短声，取6个独立变体，避免仅变调同一个声音 |
| `swishes` | artisticdude · [原始页面](https://opengameart.org/content/swishes-sound-pack) | 有轻重之分的独立武器破风；挥空不混入接触声 |
| `reload` | SpringySpringo · [原始页面](https://opengameart.org/content/gun-reload-sounds) | 气枪实录的弹匣和泵动机构，便于拆分动作 |
| `pistol` | zer0_sol · [原始页面](https://opengameart.org/content/handgun-reload-sound-effect) | 作者明确描述退匣、插匣、拉动套筒的半自动手枪拟音 |
| `firearms` | Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney · [原始页面](https://opengameart.org/content/the-free-firearm-sound-library) | 提供枪型、射击距离、单发／连发元数据的实录库，选首个独立枪响 |
| `weapons` | Jan Schupke / Vehicle · [原始页面](https://opengameart.org/content/fantasy-weapons-and-apparel-sfx-library) | 作者说明为有机录音；有明确出鞘、入鞘、皮革挤压和扣件文件名 |
| `impacts` | Kenney · [原始页面](https://kenney.nl/assets/impact-sounds) | 按木材、石面、草地、薄铁皮、厚金属、软垫和拳击分类 |
| `rpg` | Kenney · [原始页面](https://kenney.nl/assets/rpg-audio) | 衣物、束带、金属卡扣可作为机械与身体动作的细节层 |
| `music` | nene · [原始页面](https://opengameart.org/node/68238) | Rock/Metal曲目选择38–48秒的高能量段，适配10秒技能并淡出 |
| `plastic` | redpanda69 · [原始页面](https://freesound.org/people/redpanda69/sounds/686167/) | 塑料接触卡裂录音，对应轻薄路障材质；使用公开HQ预览音频 |
| `flame` | themightyglider; derived from qubodup (CC0) · [原始页面](https://opengameart.org/content/catching-fire) | 短燃烧效果适合连续喷射拼接；来源链保留上游CC0链接 |

上述来源页面于2026-10-16核对为 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)。CC0允许修改、商用和再分发；作者、来源与加工记录仍予保留。

## 枪声具体映射

| 游戏武器 | 原始录音 | 处理与选择理由 |
| --- | --- | --- |
| 步枪 | `AK-47/C_28P.wav` | AK-47近距离单发，与步枪模型相符；取0.40秒，避免连射尾音拥挤 |
| P90 | `Carl Gustav M45/G_31P.wav` | 冲锋枪近距离单发替代；缩短至0.23秒并轻微提速，保留快速武器的短瞬态；不是P90实录 |
| 手枪 | `Walther PPQ/X_39P.wav` | 9mm半自动手枪近距离单发，取0.36秒 |
| 左轮 | `Smith & Wesson 642/V_27P.wav` | .38左轮近距离单发，保留0.54秒尾声 |
| 泵动霰弹枪 | `Mossberg/N_30P.wav` | 12号霰弹枪实录，保留0.67秒；原枪为栓动型号，只使用独立枪响，不借用其操作声 |
| 狙击枪 | `Tikka/W_29P.wav` | Tikka T3栓动步枪近距离单发，保留0.70秒尾声 |
| 自动霰弹枪 | `Nova/O_21P.wav` | Benelli Nova的12号霰弹枪单发替代；仅取枪响0.43秒，机构动作由游戏自己的换弹轨道负责 |
| 重机枪 | `AK-47/C_31P.wav` | 步枪单发作为重机枪拟音替代，降速至0.84并低通5500Hz；不是对应重机枪实录 |

消防斧使用独立厚重破风加衣物层；喷火枪使用Catching fire短燃烧素材，不采用真实枪弹爆音。

## 换弹与动作同步

按现有模型的归一化换弹进度定位录音片段，接触类动作把录音的主要瞬态峰值定位到标记附近；衣物拿取类只去掉前导静音，不给未运动的机构补拉栓声。P90、手枪、狙击枪、自动霰弹枪和重机枪的标记来自已导入动画的弹匣／机构轨道；步枪和左轮来自原生pose函数。关键动作源文件摘要也写入音效清单，动作文件改变后检查会要求复核。

| 武器 | 总时长 | 分段动作起点（秒） |
| --- | --- | --- |
| 步枪 | 1.60 | magazine_out 0.192、magazine_in 1.408 |
| P90 | 1.50 | magazine_release 0.225、magazine_seat 1.005 |
| 手枪 | 1.20 | magazine_out 0.204、magazine_in 0.936 |
| 左轮 | 1.60 | cylinder_open 0.208、case_eject 0.496、speedloader_seat 1.072、cylinder_close 1.328 |
| 泵动霰弹枪 | 0.40 | shell_handling 0.088、shell_seat 0.256 |
| 狙击枪 | 1.80 | bolt_open 0.216、magazine_out 0.504、magazine_in 1.260、bolt_close 1.566 |
| 自动霰弹枪 | 2.20 | drum_out 0.176、drum_seat 2.068 |
| 重机枪 | 3.60 | box_release 0.216、box_handling 1.620、charging_handle_pull 2.664、box_seat 3.384、charging_handle_return 3.528 |
| 喷火枪 | 2.40 | tank_release 0.144、tank_handling 1.200、tank_clamp 2.256 |

- 播放器从 `reloadDuration - reload` 定位，音高固定1.0；迟到帧从对应PCM位置开始。
- 每个逐发装填循环独立播放0.4秒轨道；停止装填、切换武器、暂停、失焦或死亡时立即停止，恢复后从当前动作时间继续。
- 消防斧不生成换弹音效。步枪切换拉栓、手枪切换旋转及其音效保持移除。
- 拔刀1.1秒轨道中，实际抽刀声覆盖0.176–0.814秒；收刀0.95秒轨道中，实际入鞘声覆盖0.361–0.788秒。挥刀使用另外3个破风变体。
- 开大音乐为10秒独立轨道，普通背景音乐在大招期间压低12dB，结束后恢复。

## 每个游戏音效条目

下表覆盖全部54个替换条目。具体剪辑区间、层叠时间、增益、变速／滤波与输出文件摘要见 `assets/data/audio.json`；原始文件、上游包、节选区间和来源摘要见 `tools/audio-sources/index.json`。

| 音效文件 | 原始素材节选ID（对应上述来源包） | 选择理由 |
| --- | --- | --- |
| `death-0.wav` | `zombie-0`（zombies） | 同一CC0僵尸声包的六个独立短声，减少密集击杀时重复 |
| `death-1.wav` | `zombie-1`（zombies） | 同一CC0僵尸声包的六个独立短声，减少密集击杀时重复 |
| `death-2.wav` | `zombie-2`（zombies） | 同一CC0僵尸声包的六个独立短声，减少密集击杀时重复 |
| `death-3.wav` | `zombie-3`（zombies） | 同一CC0僵尸声包的六个独立短声，减少密集击杀时重复 |
| `death-4.wav` | `zombie-4`（zombies） | 同一CC0僵尸声包的六个独立短声，减少密集击杀时重复 |
| `death-5.wav` | `zombie-5`（zombies） | 同一CC0僵尸声包的六个独立短声，减少密集击杀时重复 |
| `weapon-rifle.wav` | `gun-rifle`（firearms） | 实录枪声的首个独立枪响，去前导静音、缩短尾声并保留峰值余量；非对应型号者为明确记录的替代拟音 |
| `weapon-p90.wav` | `gun-p90`（firearms） | 实录枪声的首个独立枪响，去前导静音、缩短尾声并保留峰值余量；非对应型号者为明确记录的替代拟音 |
| `weapon-pistol.wav` | `gun-pistol`（firearms） | 实录枪声的首个独立枪响，去前导静音、缩短尾声并保留峰值余量；非对应型号者为明确记录的替代拟音 |
| `weapon-revolver.wav` | `gun-revolver`（firearms） | 实录枪声的首个独立枪响，去前导静音、缩短尾声并保留峰值余量；非对应型号者为明确记录的替代拟音 |
| `weapon-shotgun.wav` | `gun-shotgun`（firearms） | 实录枪声的首个独立枪响，去前导静音、缩短尾声并保留峰值余量；非对应型号者为明确记录的替代拟音 |
| `weapon-sniper.wav` | `gun-sniper`（firearms） | 实录枪声的首个独立枪响，去前导静音、缩短尾声并保留峰值余量；非对应型号者为明确记录的替代拟音 |
| `weapon-auto-shotgun.wav` | `gun-auto-shotgun`（firearms） | 实录枪声的首个独立枪响，去前导静音、缩短尾声并保留峰值余量；非对应型号者为明确记录的替代拟音 |
| `weapon-heavy-machine-gun.wav` | `gun-heavy-machine-gun`（firearms） | 实录枪声的首个独立枪响，去前导静音、缩短尾声并保留峰值余量；非对应型号者为明确记录的替代拟音 |
| `weapon-axe.wav` | `cloth1`（rpg）、`swish-7`（swishes） | 厚重破风配合斧头挥动，不把命中撞击混入空挥 |
| `weapon-flamethrower.wav` | `flame`（flame） | 已有CC0燃烧素材截取为短连续喷射片段，渐入渐出控制叠加 |
| `blade-draw.wav` | `cloth1`（rpg）、`seax-unsheathe-01`（weapons） | 出鞘录音放在拔刀阶段16%至74%的实际抽刀区间 |
| `blade-sheathe.wav` | `seax-sheathe-01`（weapons）、`metalLatch`（rpg） | 入鞘录音放在收刀阶段38%至83%，末端短卡扣对应到位 |
| `blade-swing.wav` | `swish-5`（swishes） | 独立挥刀破风，主瞬态位于挥砍有效段；三变体不混入拔刀声 |
| `blade-swing-1.wav` | `swish-6`（swishes） | 独立挥刀破风，主瞬态位于挥砍有效段；三变体不混入拔刀声 |
| `blade-swing-2.wav` | `swish-8`（swishes） | 独立挥刀破风，主瞬态位于挥砍有效段；三变体不混入拔刀声 |
| `enemy-step-0.wav` | `step-concrete-0`（impacts） | 按桥面木板、坡道石面和场地草地选择对应材质的脚步录音 |
| `enemy-step-1.wav` | `step-concrete-1`（impacts） | 按桥面木板、坡道石面和场地草地选择对应材质的脚步录音 |
| `enemy-step-2.wav` | `step-concrete-2`（impacts） | 按桥面木板、坡道石面和场地草地选择对应材质的脚步录音 |
| `enemy-step-wood-0.wav` | `step-wood-0`（impacts） | 按桥面木板、坡道石面和场地草地选择对应材质的脚步录音 |
| `enemy-step-wood-1.wav` | `step-wood-1`（impacts） | 按桥面木板、坡道石面和场地草地选择对应材质的脚步录音 |
| `enemy-step-wood-2.wav` | `step-wood-2`（impacts） | 按桥面木板、坡道石面和场地草地选择对应材质的脚步录音 |
| `enemy-step-grass-0.wav` | `step-grass-0`（impacts） | 按桥面木板、坡道石面和场地草地选择对应材质的脚步录音 |
| `enemy-step-grass-1.wav` | `step-grass-1`（impacts） | 按桥面木板、坡道石面和场地草地选择对应材质的脚步录音 |
| `enemy-step-grass-2.wav` | `step-grass-2`（impacts） | 按桥面木板、坡道石面和场地草地选择对应材质的脚步录音 |
| `shove.wav` | `swish-1`（swishes） | 短轻破风，与实际推搡命中声分离 |
| `shove-hit.wav` | `impactPunch_heavy_000`（impacts）、`cloth2`（rpg） | 拳击低频撞击与衣物摩擦，用于身体推搡接触 |
| `enemy-windup.wav` | `zombie-3`（zombies） | 僵尸短声作为攻击前摇 |
| `enemy-miss.wav` | `swish-10`（swishes） | 攻击挥空仅播放短破风 |
| `enemy-impact.wav` | `impactPunch_medium_001`（impacts） | 真实接触撞击，用于近战与建筑受击 |
| `hurt.wav` | `impactSoft_heavy_000`（impacts） | 低沉软质受击，避免与铁皮、盾牌撞击混淆 |
| `cone-false.wav` | `plastic-snap`（plastic） | 路障采用塑料卡扣的短促卡裂，区别于金属共鸣 |
| `cone-true.wav` | `plastic-snap`（plastic）、`impactGeneric_light_000`（impacts） | 路障破坏叠加第二次塑料裂响和轻质散落 |
| `bucket-false.wav` | `impactTin_medium_000`（impacts） | 铁桶采用薄铁皮空腔撞击，保留轻薄共鸣 |
| `bucket-true.wav` | `impactTin_medium_002`（impacts）、`impactTin_medium_000`（impacts）、`impactMetal_light_000`（impacts） | 铁桶破坏含薄铁皮变形和金属落地尾声 |
| `shield-false.wav` | `impactMetal_heavy_000`（impacts） | 盾牌使用厚金属低沉重击，与铁桶空腔声分开 |
| `shield-true.wav` | `impactMetal_heavy_002`（impacts）、`impactPlate_heavy_002`（impacts）、`impactPlate_light_000`（impacts） | 盾牌破坏使用厚板冲击和较重散落 |
| `football-false.wav` | `impactSoft_medium_000`（impacts）、`quiver-leather-squeeze-01`（weapons） | 橄榄球护具与巨人皮盔使用软垫撞击和皮革挤压，避免金属铃响 |
| `football-true.wav` | `impactSoft_heavy_000`（impacts）、`quiver-leather-squeeze-06`（weapons）、`belt-buckle-01`（weapons） | 软质护具破坏表现束带松脱与落地，区别于塑料和金属破裂 |
| `reload-rifle.wav` | `reload-rifle`（reload） | 按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止 |
| `reload-p90.wav` | `reload-pistol-airsoft`（reload） | 按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止 |
| `reload-pistol.wav` | `reload-pistol`（pistol） | 按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止 |
| `reload-revolver.wav` | `metalLatch`（rpg）、`metalClick`（rpg）、`reload-pistol`（pistol） | 按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止 |
| `reload-shotgun.wav` | `cloth1`（rpg）、`metalClick`（rpg） | 按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止 |
| `reload-sniper.wav` | `pump`（reload）、`reload-rifle`（reload） | 按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止 |
| `reload-flamethrower.wav` | `metalLatch`（rpg）、`clothBelt`（rpg） | 按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止 |
| `reload-auto-shotgun.wav` | `reload-rifle`（reload） | 按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止 |
| `reload-heavy-machine-gun.wav` | `metalLatch`（rpg）、`clothBelt`（rpg）、`pump`（reload）、`reload-rifle`（reload） | 按实际换弹动作阶段定位；逐发装填每循环一次；暂停或取消时停止 |
| `ultimate-music.wav` | `ultimate-music`（music） | nene原创Rock/Metal短曲中选取38–48秒的高能量段，技能结束前淡出 |

## 维护与检查

- `python tools/build-cc0-audio.py`：从提交的录音节选重建，需numpy/scipy。
- `python tools/build-cc0-audio.py --check`：仅用Python标准库核对CC0来源链、源／输出摘要、PCM参数、峰值、静音、直流、动作摘要与九种换弹时长；已纳入基础门禁。
- 旧武器和近战合成脚本拒绝覆盖CC0资源；旧资源转换脚本跳过本次54个条目。
- 原始开发节选位于带 `.gdignore` 的tools目录，避免重复导入和打包；运行时只加载处理后的音频。
- 无窗口技术检查不代表音效试听、原生GPU动作观感或真人手感通过。
