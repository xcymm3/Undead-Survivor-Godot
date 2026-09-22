import { test, expect } from '@playwright/test';

const snapshot = page => page.evaluate(() => window.__survivorSnapshot);

async function clickButton(page, text) {
  await expect.poll(async () => (await snapshot(page))?.buttons.some(button => button.text.includes(text) && !button.disabled)).toBe(true);
  const button = (await snapshot(page)).buttons.find(item => item.text.includes(text) && !item.disabled);
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    canvas.y + (button.y + button.height / 2) * canvas.height / 900);
}

test('简单难度下举枪自动瞄准的自动霰弹枪角色守住水晶十波', async ({ page }, info) => {
  test.setTimeout(720_000);
  const errors = [];
  const held = new Set();
  const progress = [];
  let firing = false;
  let retreating = false;
  let retreatGoal = 0;
  let retreatStarted = 0;
  let retreatCooldownUntil = 0;
  let restocking = false;
  let sawRegen = false;
  let routeViolation = null;
  let previous = null;
  const primaryWeapon = 8;
  const primaryCapacity = 20;
  const primaryReserve = 340;
  const rack = { x: 2.4, z: 64.8 };
  page.on('pageerror', error => errors.push(String(error)));

  async function setKey(key, down) {
    if (down && !held.has(key)) {
      await page.keyboard.down(key);
      held.add(key);
    } else if (!down && held.has(key)) {
      await page.keyboard.up(key);
      held.delete(key);
    }
  }
  async function stopMoving() {
    for (const key of ['w', 'a', 's', 'd']) await setKey(key, false);
  }
  async function moveToward(state, x, z) {
    const dx = x - state.player.x;
    const dz = z - state.player.z;
    if (Math.hypot(dx, dz) < .8) {
      await stopMoving();
      return;
    }
    const length = Math.max(.001, Math.hypot(dx, dz));
    const worldX = dx / length;
    const worldZ = dz / length;
    const localX = worldX * Math.cos(state.yaw) - worldZ * Math.sin(state.yaw);
    const localY = worldX * Math.sin(state.yaw) + worldZ * Math.cos(state.yaw);
    await setKey('a', localX < -.28);
    await setKey('d', localX > .28);
    await setKey('w', localY < -.28);
    await setKey('s', localY > .28);
  }
  async function walkTo(x, z, timeout = 20_000) {
    const started = Date.now();
    let state;
    while (Date.now() - started < timeout) {
      state = await snapshot(page);
      if (Math.hypot(state.player.x - x, state.player.z - z) < .8) {
        await stopMoving();
        return;
      }
      await moveToward(state, x, z);
      await page.waitForTimeout(100);
    }
    await stopMoving();
    throw new Error(`Automated player could not reach (${x}, ${z}); stopped at (${state.player.x.toFixed(2)}, ${state.player.z.toFixed(2)})`);
  }
  async function setFiring(enabled) {
    if (enabled === firing) return;
    firing = enabled;
    if (enabled) await page.mouse.down({ button: 'left' });
    else await page.mouse.up({ button: 'left' });
  }
  await page.goto('/?autoaim=1');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  await clickButton(page, '保卫水晶');
  await page.waitForFunction(() => window.__survivorSnapshot?.map_id === 'graypine_defense');
  await clickButton(page, '简单 · 70%');
  await clickButton(page, '单人防守');
  await page.waitForFunction(() => window.__survivorSnapshot?.mode === 'defense' && window.__survivorSnapshot?.running);
  expect((await snapshot(page)).defense.difficulty).toBe('easy');

  // Walk to the physical armory, aim at the automatic shotgun through the QA
  // camera helper, and hold the real interaction key to equip it.
  await walkTo(rack.x, rack.z);
  await setKey('e', true);
  await page.waitForFunction(weapon => window.__survivorSnapshot?.player?.primary === weapon, primaryWeapon, { timeout: 10_000 });
  await setKey('e', false);

  // Select the scoped primary for the bridge's long firing lane, then walk to the lever.
  await page.keyboard.press('1');
  await page.waitForFunction(weapon => window.__survivorSnapshot?.player?.weapon === weapon && window.__survivorSnapshot.player.switch <= 0, primaryWeapon);
  await page.mouse.down({ button: 'middle' });
  await page.mouse.up({ button: 'middle' });
  await page.waitForFunction(() => window.__survivorSnapshot.player.aim);
  await walkTo(6, 58);
  await walkTo(6, 51.2);
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot?.defense?.started, null, { timeout: 10_000 });
  await page.keyboard.up('e');

  const startedAt = Date.now();
  while (Date.now() - startedAt < 690_000) {
    const state = await snapshot(page);
    if (!state?.player) {
      await page.waitForTimeout(250);
      continue;
    }
    if (previous && state.cleared > previous.cleared) {
      console.log(`[波次检查] 第 ${state.cleared} 波完成 | 用时 ${state.elapsed.toFixed(1)} 秒 | 玩家 ${state.player.hp} HP | 水晶 ${state.defense.crystal_hp} HP | 命中 ${state.player.hits}/${state.player.shots}`);
      expect(routeViolation, `Route must remain valid through wave ${state.cleared}`).toBeNull();
    }
    if (state.won || state.failed || state.finished) break;

    for (const enemy of state.enemies) {
      const onBridge = enemy.z > -62 && enemy.z < -28;
      const besideRamp = enemy.z >= -28 && enemy.z < -10;
      if ((onBridge && Math.abs(enemy.x) > 3.12) || (besideRamp && Math.abs(enemy.x) > 4.62)) {
        routeViolation = { wave: state.wave, enemy, player: state.player };
      }
    }

    const remainingPrimaryAmmo = state.player.ammo[primaryWeapon] + state.player.reserves[primaryWeapon];
    if (!restocking && state.cleared < 10 && remainingPrimaryAmmo <= primaryCapacity) restocking = true;
    if (restocking) {
      await setFiring(false);
      const atRack = Math.hypot(state.player.x - rack.x, state.player.z - rack.z) < .9;
      if (!atRack) {
        await setKey('e', false);
        await moveToward(state, rack.x, rack.z);
      } else {
        await stopMoving();
        await setKey('e', true);
      }
      if (state.player.ammo[primaryWeapon] === primaryCapacity && state.player.reserves[primaryWeapon] === primaryReserve) {
        await setKey('e', false);
        restocking = false;
      }
      previous = state;
      await page.waitForTimeout(250);
      continue;
    }

    const nearest = state.enemies.reduce((best, enemy) => Math.min(best,
      Math.hypot(enemy.x - state.player.x, enemy.z - state.player.z)), Infinity);
    if (!retreating && state.elapsed >= retreatCooldownUntil && state.player.hp <= 40 && state.defense.crystal_hp >= 400) {
      retreating = true;
      retreatGoal = Math.min(65, state.player.hp + 10);
      retreatStarted = state.elapsed;
    }
    if (retreating && state.player.hp < retreatGoal - 10) retreatGoal = Math.min(65, state.player.hp + 10);
    if (previous && retreating && state.player.z > 51 && state.player.hp > previous.player.hp) sawRegen = true;

    if (retreating) {
      const inFallback = state.player.z > 52 && state.player.x > 10.5;
      const healing = state.player.hp < retreatGoal && state.defense.crystal_hp >= 400;
      if (inFallback && ((!healing && state.elapsed - retreatStarted >= 6) || state.defense.crystal_hp < 500)) {
        retreating = false;
        retreatCooldownUntil = state.elapsed + 10;
        continue;
      }
      await setFiring(inFallback && !healing && state.aim_target >= 0);
      if (!inFallback) await moveToward(state, 12, 53.5);
      else await stopMoving();
      if (nearest < 4.2) await page.mouse.click(480, 300, { button: 'right' });
    } else {
      await setFiring(state.aim_target >= 0);
      await moveToward(state, 8, 53.5);
      if (nearest < 4.2) await page.mouse.click(480, 300, { button: 'right' });
    }

    if (!previous || previous.wave !== state.wave || previous.cleared !== state.cleared || Math.floor(previous.elapsed / 20) !== Math.floor(state.elapsed / 20)) {
      progress.push({ elapsed: state.elapsed, wave: state.wave, cleared: state.cleared, hp: state.player.hp,
        crystal: state.defense.crystal_hp, enemies: state.enemies.length, retreating });
    }
    previous = state;
    await page.waitForTimeout(150);
  }

  await setFiring(false);
  await stopMoving();
  for (const key of held) await page.keyboard.up(key);
  const result = await snapshot(page);
  await info.attach('defense-playthrough.json', { body: Buffer.from(JSON.stringify({ progress, result, sawRegen, routeViolation }, null, 2)), contentType: 'application/json' });
  expect(errors).toEqual([]);
  expect(routeViolation, 'No enemy may be separated or shoved off the authored route').toBeNull();
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
