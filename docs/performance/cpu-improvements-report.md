# 四项CPU优化对照结果

提交：64252b4156cacd08f635bceeafc277bbc984949b；冻结源码SHA-256：e15afeef8a57441299a723ac28c83d8369d28f969bb987db2c9c977640a2e3d1。硬件：12th Gen Intel(R) Core(TM) i5-1235U。无窗口CPU测试，没有GPU数据。

prechange为1940134提交的原始simulation/main/arena；其余独立方案只启用目标缓存、射线索引、避让限额或路径限额；cpu_all在本报告表示四项全部启用。每个副本及补丁哈希见source-manifest.json。

| 方案 | 场景 | 五轮配对P95减少中位数 | 改善轮数 |
|---|---|---:|---:|
| cpu_target | movement | -7.19% | 0/5 |
| cpu_target | bridge | -1.56% | 0/5 |
| cpu_target | rifle | -0.47% | 0/5 |
| cpu_target | auto-shotgun | -1.02% | 2/5 |
| cpu_ray | movement | -5.35% | 0/5 |
| cpu_ray | bridge | -5.51% | 0/5 |
| cpu_ray | rifle | 2.21% | 5/5 |
| cpu_ray | auto-shotgun | 14.31% | 5/5 |
| cpu_crowd | movement | -4.44% | 0/5 |
| cpu_crowd | bridge | -5.80% | 0/5 |
| cpu_crowd | rifle | 1.24% | 4/5 |
| cpu_crowd | auto-shotgun | -0.37% | 2/5 |
| cpu_paths | movement | -6.39% | 0/5 |
| cpu_paths | bridge | -1.73% | 0/5 |
| cpu_paths | rifle | -0.00% | 2/5 |
| cpu_paths | auto-shotgun | 10.78% | 5/5 |
| cpu_all | movement | -1.14% | 1/5 |
| cpu_all | bridge | 11.48% | 5/5 |
| cpu_all | rifle | 3.28% | 5/5 |
| cpu_all | auto-shotgun | 12.39% | 5/5 |

## 正式300只长采样

| 方案 | 场景 | 平均/P95/P99（轮中位数）ms | 最坏尖峰ms |
|---|---|---:|---:|
| prechange | movement | 77.01/86.25/88.47 | 153.65 |
| prechange | bridge | 117.50/140.99/148.95 | 674.75 |
| prechange | rifle | 104.98/167.61/173.18 | 190.41 |
| prechange | auto-shotgun | 129.17/413.54/702.71 | 739.80 |
| cpu_target | movement | 80.30/92.43/94.92 | 155.67 |
| cpu_target | bridge | 119.11/143.03/150.90 | 670.39 |
| cpu_target | rifle | 107.43/168.06/175.02 | 189.43 |
| cpu_target | auto-shotgun | 131.79/443.66/689.04 | 727.26 |
| cpu_ray | movement | 78.89/90.68/93.62 | 161.66 |
| cpu_ray | bridge | 124.14/148.93/157.47 | 667.64 |
| cpu_ray | rifle | 105.90/163.32/169.45 | 173.38 |
| cpu_ray | auto-shotgun | 126.64/355.40/624.97 | 673.07 |
| cpu_crowd | movement | 77.70/89.74/93.16 | 167.44 |
| cpu_crowd | bridge | 121.82/149.83/158.93 | 678.70 |
| cpu_crowd | rifle | 106.13/165.53/173.24 | 179.20 |
| cpu_crowd | auto-shotgun | 130.31/416.25/702.48 | 724.72 |
| cpu_paths | movement | 80.38/92.19/94.47 | 98.97 |
| cpu_paths | bridge | 123.86/143.44/147.74 | 152.72 |
| cpu_paths | rifle | 106.76/167.95/174.14 | 178.94 |
| cpu_paths | auto-shotgun | 131.03/385.36/701.00 | 849.24 |
| cpu_all | movement | 76.37/87.23/90.16 | 95.92 |
| cpu_all | bridge | 112.41/124.45/128.82 | 147.00 |
| cpu_all | rifle | 104.13/162.02/168.41 | 173.09 |
| cpu_all | auto-shotgun | 125.23/357.79/633.54 | 690.79 |

## 短采样、动态与十分钟资源周转

| 案例 | 人数 | 场景 | 平均/P95/P99 ms | 模拟秒 | 节点峰值 | 路径单步最大/排队峰值 |
|---|---:|---|---:|---:|---:|---:|
| short-prechange | 50 | movement | 13.93/15.47/16.25 | 5.00 | 2972 | 0/0 |
| short-prechange | 50 | bridge | 20.75/27.07/28.63 | 5.00 | 2972 | 0/0 |
| short-prechange | 50 | rifle | 25.23/45.40/53.48 | 5.00 | 2972 | 0/0 |
| short-prechange | 100 | movement | 26.43/28.92/29.71 | 5.00 | 3172 | 0/0 |
| short-prechange | 100 | bridge | 38.58/48.61/51.23 | 5.00 | 3172 | 0/0 |
| short-prechange | 100 | rifle | 45.01/81.04/98.17 | 5.00 | 3172 | 0/0 |
| short-prechange | 200 | movement | 52.73/57.41/58.48 | 5.00 | 3572 | 0/0 |
| short-prechange | 200 | bridge | 74.39/96.49/103.08 | 5.00 | 3572 | 0/0 |
| short-prechange | 200 | rifle | 73.78/116.14/138.45 | 5.00 | 3572 | 0/0 |
| short-cpu_target | 50 | movement | 14.65/16.29/16.88 | 5.00 | 2972 | 0/0 |
| short-cpu_target | 50 | bridge | 20.44/26.58/28.01 | 5.00 | 2972 | 0/0 |
| short-cpu_target | 50 | rifle | 25.29/45.64/53.05 | 5.00 | 2972 | 0/0 |
| short-cpu_target | 100 | movement | 27.87/30.24/31.02 | 5.00 | 3172 | 0/0 |
| short-cpu_target | 100 | bridge | 38.25/49.15/51.17 | 5.00 | 3172 | 0/0 |
| short-cpu_target | 100 | rifle | 45.82/80.32/96.64 | 5.00 | 3172 | 0/0 |
| short-cpu_target | 200 | movement | 56.22/60.83/62.36 | 5.00 | 3572 | 0/0 |
| short-cpu_target | 200 | bridge | 75.69/95.40/100.81 | 5.00 | 3572 | 0/0 |
| short-cpu_target | 200 | rifle | 74.50/113.56/137.84 | 5.00 | 3572 | 0/0 |
| short-cpu_ray | 50 | movement | 14.55/16.06/17.04 | 5.00 | 2972 | 0/0 |
| short-cpu_ray | 50 | bridge | 21.43/27.55/29.08 | 5.00 | 2972 | 0/0 |
| short-cpu_ray | 50 | rifle | 25.77/44.25/54.20 | 5.00 | 2972 | 0/0 |
| short-cpu_ray | 100 | movement | 27.62/29.85/31.12 | 5.00 | 3172 | 0/0 |
| short-cpu_ray | 100 | bridge | 40.17/50.08/53.23 | 5.00 | 3172 | 0/0 |
| short-cpu_ray | 100 | rifle | 47.22/80.81/100.83 | 5.00 | 3172 | 0/0 |
| short-cpu_ray | 200 | movement | 56.56/60.94/62.37 | 5.00 | 3572 | 0/0 |
| short-cpu_ray | 200 | bridge | 79.23/99.94/106.47 | 5.00 | 3572 | 0/0 |
| short-cpu_ray | 200 | rifle | 75.07/113.60/136.89 | 5.00 | 3572 | 0/0 |
| short-cpu_crowd | 50 | movement | 14.97/16.69/17.66 | 5.00 | 2972 | 0/0 |
| short-cpu_crowd | 50 | bridge | 22.38/28.42/29.27 | 5.00 | 2972 | 0/0 |
| short-cpu_crowd | 50 | rifle | 26.12/43.26/54.34 | 5.00 | 2972 | 0/0 |
| short-cpu_crowd | 100 | movement | 28.74/31.95/33.13 | 5.00 | 3172 | 0/0 |
| short-cpu_crowd | 100 | bridge | 42.38/53.19/56.39 | 5.00 | 3172 | 0/0 |
| short-cpu_crowd | 100 | rifle | 49.07/81.95/100.45 | 5.00 | 3172 | 0/0 |
| short-cpu_crowd | 200 | movement | 55.79/61.39/63.53 | 5.00 | 3572 | 0/0 |
| short-cpu_crowd | 200 | bridge | 83.20/103.85/108.87 | 5.00 | 3572 | 0/0 |
| short-cpu_crowd | 200 | rifle | 76.83/116.98/138.87 | 5.00 | 3572 | 0/0 |
| short-cpu_paths | 50 | movement | 14.81/16.20/17.01 | 5.00 | 2972 | 12/0 |
| short-cpu_paths | 50 | bridge | 21.78/26.77/38.27 | 5.00 | 2972 | 12/38 |
| short-cpu_paths | 50 | rifle | 25.41/42.36/52.64 | 5.00 | 2972 | 12/37 |
| short-cpu_paths | 100 | movement | 29.03/31.64/32.08 | 5.00 | 3172 | 12/10 |
| short-cpu_paths | 100 | bridge | 41.18/49.40/59.59 | 5.00 | 3172 | 12/88 |
| short-cpu_paths | 100 | rifle | 46.82/78.58/97.65 | 5.00 | 3172 | 12/80 |
| short-cpu_paths | 200 | movement | 57.56/61.77/65.16 | 5.00 | 3572 | 12/37 |
| short-cpu_paths | 200 | bridge | 81.37/90.88/99.09 | 5.00 | 3572 | 12/188 |
| short-cpu_paths | 200 | rifle | 76.12/119.70/138.37 | 5.00 | 3572 | 12/98 |
| short-cpu_all | 50 | movement | 14.45/16.28/16.95 | 5.00 | 2972 | 12/0 |
| short-cpu_all | 50 | bridge | 20.68/25.05/38.23 | 5.00 | 2972 | 12/38 |
| short-cpu_all | 50 | rifle | 25.63/42.55/56.11 | 5.00 | 2972 | 12/37 |
| short-cpu_all | 100 | movement | 27.57/30.58/31.89 | 5.00 | 3172 | 12/10 |
| short-cpu_all | 100 | bridge | 38.54/45.84/56.10 | 5.00 | 3172 | 12/88 |
| short-cpu_all | 100 | rifle | 46.62/79.48/104.27 | 5.00 | 3172 | 12/80 |
| short-cpu_all | 200 | movement | 54.19/59.36/61.17 | 5.00 | 3572 | 12/37 |
| short-cpu_all | 200 | bridge | 76.33/87.18/95.98 | 5.00 | 3572 | 12/188 |
| short-cpu_all | 200 | rifle | 74.94/116.97/136.35 | 5.00 | 3572 | 12/98 |
| dynamic-prechange | 300 | mixed | 97.09/102.55/104.77 | 9.92 | 3972 | 0/0 |
| dynamic-prechange | 300 | boss | 99.18/106.54/108.65 | 9.73 | 3972 | 0/0 |
| dynamic-prechange | 300 | lifecycle | 104.54/114.65/119.55 | 9.22 | 4072 | 0/0 |
| dynamic-cpu_target | 300 | mixed | 99.21/105.88/108.58 | 9.72 | 3972 | 0/0 |
| dynamic-cpu_target | 300 | boss | 101.75/109.44/112.56 | 9.48 | 3972 | 0/0 |
| dynamic-cpu_target | 300 | lifecycle | 107.37/117.74/121.01 | 8.98 | 4072 | 0/0 |
| dynamic-cpu_ray | 300 | mixed | 100.04/107.04/110.05 | 9.65 | 3972 | 0/0 |
| dynamic-cpu_ray | 300 | boss | 102.21/109.73/112.46 | 9.45 | 3972 | 0/0 |
| dynamic-cpu_ray | 300 | lifecycle | 107.22/117.63/121.79 | 9.00 | 4072 | 0/0 |
| dynamic-cpu_crowd | 300 | mixed | 96.46/101.48/103.53 | 9.98 | 3972 | 0/0 |
| dynamic-cpu_crowd | 300 | boss | 98.96/104.24/105.55 | 9.73 | 3972 | 0/0 |
| dynamic-cpu_crowd | 300 | lifecycle | 102.36/111.09/115.35 | 9.42 | 4072 | 0/0 |
| dynamic-cpu_paths | 300 | mixed | 99.60/107.19/109.73 | 9.68 | 3972 | 12/1 |
| dynamic-cpu_paths | 300 | boss | 102.21/109.35/112.44 | 9.43 | 3972 | 12/3 |
| dynamic-cpu_paths | 300 | lifecycle | 106.32/116.09/119.08 | 9.08 | 4072 | 12/25 |
| dynamic-cpu_all | 300 | mixed | 97.00/103.27/104.57 | 9.93 | 3972 | 12/0 |
| dynamic-cpu_all | 300 | boss | 100.70/105.87/106.95 | 9.58 | 3972 | 12/3 |
| dynamic-cpu_all | 300 | lifecycle | 103.80/112.96/116.57 | 9.28 | 4072 | 12/20 |
| endurance-prechange | 300 | lifecycle | 110.73/118.64/122.37 | 87.15 | 4072 | 0/0 |
| endurance-cpu_all | 300 | lifecycle | 110.81/118.72/121.31 | 87.08 | 4072 | 12/25 |

计时是CPU分段合计，不是渲染FPS。每场预热后采样，核心长采样每场墙钟60秒、5轮，轮次反转方案和场景顺序。固定人口场景每600步恢复起点；较快版本推进更多模拟时间，移动/拥堵状态分布仍可能不同。原版无预算统计，不表示原版没有A*调用。远处索敌最多延后约0.1–0.2秒；路径排队可能短暂延迟，保留实际通行检查并优先处理近处/被堵敌人，年龄防饥饿。避让允许更紧密重叠，可能影响防线难度。动态BOSS样本需结合模拟时间和人口，不能直接排名。十分钟测试仅为资源周转，不是完整自然对局。对象池及骨骼简化未改。原始数据、每步命令、退出码和输出见audit.jsonl、step-*.log、cli.log。
