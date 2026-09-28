import { test, expect } from '@playwright/test';

for (const scenario of ['gate', 'kills', 'destroy', 'mine', 'support']) {
  test(`建筑实机交互：${scenario}`, async ({ page }, info) => {
    test.setTimeout(240_000);
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', msg => {
      if (msg.type() === 'error' && /SCRIPT ERROR|Parse Error|Invalid|Assertion/i.test(msg.text())) errors.push(msg.text());
    });
    await page.goto(`/?structureCase=${scenario}`);
    await page.waitForFunction(() => window.__structureReport?.done || window.__structureReport?.failed || window.__structureReport?.time > 90, null, { timeout: 210_000 });
    const report = await page.evaluate(() => window.__structureReport);
    await info.attach('combat-report', { body: JSON.stringify(report, null, 2), contentType: 'application/json' });
    await page.waitForTimeout(500);
    await page.screenshot({ path: info.outputPath(`${scenario}.png`) });
    expect(errors).toEqual([]);
    expect(report.done).toBe(true);
    expect(report.failed).toBe(false);
    expect(report.player_shots).toBe(0);
    if (scenario === 'support') {
      expect(report.support).toHaveLength(27);
      for (const sample of report.support) {
        expect(sample.attacking_gate, JSON.stringify(sample)).toBe(true);
        expect(sample.rays.some(ray => ray.distance <= 10), JSON.stringify(sample)).toBe(true);
        if (['crawler', 'imp'].includes(sample.kind)) {
          expect(sample.rays.every(ray => ray.blocker === 'BridgeGate/StructureCollision')).toBe(true);
          expect(sample.damage).toBe(0);
          expect(sample.shots).toBe(0);
        } else {
          expect(sample.rays.every(ray => ray.blocker === '')).toBe(true);
          expect(sample.damage, JSON.stringify(sample)).toBeGreaterThan(0);
          expect(sample.shots).toBeGreaterThan(0);
        }
      }
    } else if (scenario === 'gate') {
      expect(report.bypass).toBe(false);
      expect(report.targets).toContain('bridge_gate');
      expect(report.gate_hp).toBe(0);
      expect(report.crossed).toBe(true);
    } else if (scenario === 'kills') {
      expect(report.shots).toBeGreaterThan(0);
      expect(report.kills).toBe(2);
    } else if (scenario === 'destroy') {
      expect(report.targets).toContain('turret_left');
      expect(report.turret_hp).toBe(0);
      expect(report.wreck_visible).toBe(true);
      expect(report.wreck_tilt).toBeGreaterThan(1);
      expect(report.wreck_collision).toBe(0);
    } else {
      expect(report.mine_triggered).toBe(true);
      expect(report.mine_spent).toBe(true);
      expect(report.prime_edges).toBe(1);
      expect(report.explosions).toBe(1);
      expect(report.kills).toBe(1);
      expect(report.second_hp).toBe(report.normal_hp);
    }
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  });
}
