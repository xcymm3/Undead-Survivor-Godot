import { test, expect } from '@playwright/test';
import { createHash } from 'node:crypto';

test('right shove cooldown ring and middle toggle use real input', { tag: '@core' }, async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', msg => { if (/^(SCRIPT ERROR|ERROR):/.test(msg.text())) errors.push(msg.text()); });
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90000 });
  const button = await page.evaluate(() => window.__survivorSnapshot.buttons.find(b => b.text === '单人模式'));
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x+(button.x+button.width/2)*canvas.width/1440, canvas.y+(button.y+button.height/2)*canvas.height/900);
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.hp > 0);
  await page.mouse.down({ button: 'middle' }); await page.mouse.up({ button: 'middle' });
  await page.waitForFunction(() => window.__survivorSnapshot.player.aim);
  await page.mouse.down({ button: 'middle' }); await page.mouse.up({ button: 'middle' });
  await page.waitForFunction(() => !window.__survivorSnapshot.player.aim);
  await page.keyboard.down('w'); await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot.campaign.bar_removed);
  await page.keyboard.up('e');
  await page.waitForTimeout(100);
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot.campaign.departed, null, {timeout:15000});
  await page.keyboard.up('w'); await page.keyboard.up('e');
  for (let count = 1; count <= 3; count++) {
    await page.waitForFunction(() => window.__survivorSnapshot.player.shove_gap === 0);
    await page.mouse.down({ button: 'right' }); await page.mouse.up({ button: 'right' });
    await page.waitForFunction(count => count === 3 ? window.__survivorSnapshot.player.shove_cd > 0 : window.__survivorSnapshot.player.shove_count === count, count);
  }
  const before = await page.evaluate(() => window.__survivorSnapshot.player.shove_cd);
  await page.mouse.down({ button: 'right' }); await page.mouse.up({ button: 'right' });
  expect(await page.evaluate(() => window.__survivorSnapshot.player.shove_cd)).toBeLessThanOrEqual(before);
  await page.screenshot({ path: info.outputPath('shove-cooldown-ring.png') });
  await page.waitForFunction(() => window.__survivorSnapshot.player.shove_cd === 0);
  await page.mouse.down({ button: 'right' }); await page.mouse.up({ button: 'right' });
  await page.waitForFunction(() => window.__survivorSnapshot.player.shove_count === 1);
  await page.screenshot({ path: info.outputPath('shove-ready-again.png') });
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});

test('enemy running and strike software pose evidence', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', msg => { if (/^(SCRIPT ERROR|ERROR):/.test(msg.text())) errors.push(msg.text()); });
  await page.setViewportSize({ width:1280, height:800 });
  await page.goto('/?poses=1');
  await page.waitForFunction(() => window.__poseReady, null, { timeout:90000 });
  const poseHashes = new Set();
  for (const [name, pose] of [
    ['run-left',{enemy:'run',time:.1}],['run-right',{enemy:'run',time:.4}],
    ['windup',{enemy:'attack',attack:.12}],['strike',{enemy:'attack',attack:.5}],['recover',{enemy:'attack',attack:.8}],
  ]) {
    await page.evaluate(pose => { window.__poseRequest = pose; },pose);
    await page.waitForFunction(pose => JSON.stringify(window.__poseRendered) === JSON.stringify(pose),pose);
    const state = await page.evaluate(() => window.__enemyPose);
    expect(state).toMatchObject({count:1,visible:1,focused:true});
    await info.attach(name+"-state",{body:JSON.stringify(state),contentType:"application/json"});

    await page.screenshot({ path:info.outputPath(name+'.png') });
    const crop = await page.screenshot({clip:{x:140,y:260,width:440,height:540}});
    poseHashes.add(createHash('sha256').update(crop).digest('hex'));

  }
  expect(poseHashes.size, "Each staged enemy pose must change the rendered enemy region").toBe(5);
  for (const kind of ['normal','cone','bucket','imp','shield','berserker','giant','football']) {
    const pose = {enemy:'run',enemy_kind:kind,time:.4};
    await page.evaluate(pose => { window.__poseRequest = pose; },pose);
    await page.waitForFunction(pose => JSON.stringify(window.__poseRendered) === JSON.stringify(pose),pose);
    expect(await page.evaluate(() => window.__enemyPose)).toMatchObject({count:1,visible:1});
    await page.screenshot({path:info.outputPath('kind-'+kind+'.png')});
  }
  expect(errors).toEqual([]);
});
