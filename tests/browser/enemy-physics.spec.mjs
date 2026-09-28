import { test, expect } from '@playwright/test';
import { writeFileSync } from 'node:fs';

for (const scenario of ['combat', 'death', 'entries', '50', '100', '200']) {
  test(`僵尸角色碰撞与导航：${scenario}`, async ({ page }, info) => {
    test.setTimeout(360_000);
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', msg => {
      if (msg.type() === 'error' && /SCRIPT ERROR|Parse Error|Invalid|Assertion/i.test(msg.text())) errors.push(msg.text());
    });
    await page.goto(`/?crowdCase=${scenario}`);
    await page.waitForFunction(() => window.__enemyPhysicsReport?.done || window.__enemyPhysicsReport?.failed, null, { timeout: 330_000 });
    const report = await page.evaluate(() => window.__enemyPhysicsReport);
    writeFileSync(`artifacts/enemy-physics-${scenario}.json`, JSON.stringify(report, null, 2));
    await info.attach('physics-report', { body: JSON.stringify(report, null, 2), contentType: 'application/json' });
    expect(errors).toEqual([]);
    expect(report.done, JSON.stringify(report)).toBe(true);
    expect(report.failed).toBe(false);
    if (scenario === 'combat') {
      expect(report.combat).toHaveLength(14);
      for (const sample of report.combat) {
        expect(sample.damage, JSON.stringify(sample)).toBeGreaterThan(0);
        expect(sample.targeted, JSON.stringify(sample)).toBe(sample.target);
      }
    } else if (scenario === 'death') {
      expect(report.death).toMatchObject({ layer: 0, mask: 0, peer_layer: 0, disabled: true, released: true, crossed: true });
      expect(report.death.neighbour_movement).toBeLessThan(.01);
    } else {
      expect(report.issues, JSON.stringify(report.issues)).toEqual([]);
      expect(report.progress).toHaveLength(scenario === 'entries' ? 20 : Number(scenario));
      for (const enemy of report.progress) {
        expect(enemy.moved, JSON.stringify(enemy)).toBeGreaterThan(.5);
        expect(enemy.physical_attempts, JSON.stringify(enemy)).toBeGreaterThan(10);
      }
      if (scenario === 'entries') {
        for (const enemy of report.progress) expect(Number(enemy.pos.split(',')[1].replace(')', '')), JSON.stringify(enemy)).toBeGreaterThan(-50);
      } else {
        expect(report.live).toBe(Number(scenario));
        expect(report.rear_attempts).toBeGreaterThan(0);
        expect(report.rear_attacks).toBe(0);
        expect(report.attack_frames).toBeGreaterThan(0);
        expect(report.physics_ms.samples).toBeGreaterThan(500);
        expect(report.simulation_ms.samples).toBe(report.physics_ms.samples);
        expect(report.optimization.slots).toBe(Number(scenario));
        expect(report.optimization.early_wakes).toBeGreaterThan(0);
        console.log(`${scenario} 敌人物理耗时(ms): ${JSON.stringify(report.physics_ms)}`);
        console.log(`${scenario} 房主 simulation.step 耗时(ms): ${JSON.stringify(report.simulation_ms)}`);
      }
    }
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  });
}
