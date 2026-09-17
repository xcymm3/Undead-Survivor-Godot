import { readFile, writeFile } from 'node:fs/promises';

const { weapons } = JSON.parse(await readFile('assets/data/rules.json', 'utf8'));
const report = JSON.parse(await readFile('artifacts/all-weapons-acceptance.json', 'utf8'));
if (report.runs.length !== weapons.length * 2 || report.failures.length) throw new Error('Incomplete weapon comparison');
const result = run => `${run.won ? '通关' : run.failed ? '死亡' : '超时'} / ${run.seconds.toFixed(1)} 秒 / ${run.kills} 杀`;
const rows = weapons.map(w => {
  const cases = report.runs.filter(r => r.id === w.id);
  return `| ${w.label} | ${w.tier} | ${result(cases.find(r => r.party === 1))} | ${result(cases.find(r => r.party === 2))} |`;
});
const damageRows = weapons.map(w => {
  const damage = w.damage * (w.kind === 'melee' ? 1 : w.pellets);
  return `| ${w.label} | ${damage}${w.pelletTargets ? `（${w.damage} × ${w.pellets}）` : ''} | ${(damage / w.interval).toFixed(0)} | ${w.capacity} | ${w.shellReload ? '每发 ' : ''}${w.reloadDuration} 秒 |`;
});
const body = `# 全武器比较

本轮 ${report.runs.length} 个样本中 ${report.runs.filter(r => r.won).length} 个通关、${report.runs.filter(r => r.failed).length} 个死亡、${report.runs.filter(r => r.timeout).length} 个超时。专项检查通过表示样本完整且没有其他武器代打，不代表所有武器都能独立通关。

每种武器单人、双人各一个 71245 种子样本。开局及路上枪械全部替换成该武器，正常弹药、医疗与推击，不允许其他枪/斧子或手雷代打。普通手枪虽然不在正常夜路 B/A 池中，也测试了受控样本。正常混合装备通关另见 balance-acceptance.json；不能把单武器死亡当作混合装备无法通关，也不能将单次生存时间直接当成武器排名。

| 武器 | 等级 | 单人（结果 / 时间 / 击杀） | 双人（结果 / 时间 / 击杀） |
| --- | --- | --- | --- |
${rows.join('\n')}

## 数值与定位

下列理论输出只计算近距离全弹命中躯干，不含装填停顿、爆头、护甲、穿透额外目标、火焰多目标和散布损失；消防斧的一次挥击对同一目标只计 100，不能把模型的三条取样线当三倍伤害。模拟以 0.05 秒步长运行，实际射速还受输入及帧步进影响。

| 武器 | 单发/挥击标称伤害 | 理论瞬时每秒伤害 | 弹仓 | 装填时间 |
| --- | --- | --- | --- | --- |
${damageRows.join('\n')}

- 步枪与重机枪标称躯干瞬时输出均为 500/秒。步枪普通爆头 120，可一发解决普通僵尸；重机枪爆头 90，通常需要两发，但 100 发弹仓比步枪 30 发更适合连续压制。建议先观察重机枪备弹和换弹窗口，避免其成为唯一稳定主武器。
- P90 标称 333/秒，约为步枪的三分之二；45 发弹仓缓解装填，单发 30 对高血量特殊怪吃亏。可考虑保持 B 级定位、改善其对普通怪的续航或移动射击手感，而不是一并提高所有枪伤害。
- 左轮单发 150、无限备弹，适合处理漏怪与主武器断弹；6 发弹仓及 1.6 秒装填使其难以独立承受大群。普通手枪仅 50/发且有限备弹，目前也不会正常掉落；若重新加入，应先确定它相对左轮的射速、弹仓或补给优势。
- 泵喷近距离理想一发 600，自动喷 544；自动喷间隔 0.36 秒，对比泵喷 0.8 秒，理想近距离输出约为两倍。两者散布、8～24 米衰减和护甲阻挡穿透都会降低实战输出。建议优先改善泵喷的可靠近距离命中与装填窗口，自动喷暂不加伤害，避免 A/B 差距继续扩大。
- 狙击枪单发 280、爆头倍率 3，适合远处特殊怪；5 发弹仓、慢射速且没有群体穿透，不适合单独守近距离尸潮。可考虑给普通怪有限穿透，或明确其为队伍中的特殊怪处理武器。
- 喷火枪当前是 12 米穿透射线，不是宽锥形火焰区域；密集正面队列能受益，被多方向包围则差。建议后续改为短程锥形覆盖及受限点燃伤害，让它与步枪有实际区别。
- 消防斧普通怪一击必杀、无弹药消耗，但仅约 2.33 米范围。适合作为近身补刀与配合推击的 C 级备用；不建议用它独立通关的表现倒推主武器伤害。
- 手雷不计入单枪专项；普通路线可正常使用。当前免自伤和友伤，允许近脚投掷解围，建议先由真人确认这种操作是否过强，再决定是否增加自伤或调整控制。

以上是建议，本轮没有额外修改枪械伤害、散布、备弹或等级。单个种子、固定策略及完美瞄准无法覆盖真人首次游玩差异；建议优先测试泵喷近身可靠性、喷火枪覆盖方式、狙击枪的团队作用。
`;
await writeFile('artifacts/weapon-comparison.md', body);
console.log(`WEAPON COMPARISON: ${report.runs.length} samples, ${report.runs.filter(r => r.won).length} wins; all outcomes retained.`);
