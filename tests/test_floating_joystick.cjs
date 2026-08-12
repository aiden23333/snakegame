const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome' });
  const page = await browser.newPage({ viewport: { width: 390, height: 780 } });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));

  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'networkidle' });
  await page.waitForSelector('#startBtn');

  // 选 easy（穿墙）模式，避免测试中撞墙误死
  await page.click('.seg-btn[data-diff="easy"]');

  // 开始前摇杆必须隐藏
  const hiddenBefore = await page.$eval('#joystick', el => getComputedStyle(el).display === 'none');
  console.log('joystick hidden before start:', hiddenBefore);

  await page.click('#startBtn');
  await page.waitForTimeout(200);

  // 画布与触控区位置：确认触控区在画布下方（不重叠棋盘）
  const layout = await page.evaluate(() => {
    const cw = document.querySelector('.canvas-wrap').getBoundingClientRect();
    const zr = document.getElementById('joystickZone').getBoundingClientRect();
    return { cwBottom: cw.bottom, zrTop: zr.top, zrBottom: zr.bottom, zrLeft: zr.left, zrRight: zr.right };
  });
  const zoneBelowCanvas = layout.zrTop >= layout.cwBottom - 1;
  console.log('zone below canvas:', zoneBelowCanvas, JSON.stringify(layout));

  // 在触控区中心落指点
  const fallX = Math.round((layout.zrLeft + layout.zrRight) / 2);
  const fallY = Math.round((layout.zrTop + layout.zrBottom) / 2);

  async function steerAndCheck(label, dx, dy, expectDir) {
    // 落点 -> 显示摇杆
    await page.mouse.move(fallX, fallY);
    await page.mouse.down();
    const shown = await page.$eval('#joystick', el => getComputedStyle(el).display !== 'none');
    const center = await page.$eval('#joystick', el => {
      const r = el.getBoundingClientRect();
      return { cx: r.left + r.width / 2, cy: r.top + r.height / 2 };
    });
    const centerMatchesFall = Math.abs(center.cx - fallX) < 2 && Math.abs(center.cy - fallY) < 2;

    // 拖到目标方向
    await page.mouse.move(fallX + dx, fallY + dy);
    // 等 tick 把 nextDirection 提交为 direction
    await page.waitForTimeout(260);
    const dir = await page.evaluate(() => window.__snake.state.direction);
    const dirOk = dir.x === expectDir.x && dir.y === expectDir.y;

    // 摇杆整体应位于触控区内（不越界、不遮挡棋盘）
    const inZone = await page.evaluate(() => {
      const j = document.getElementById('joystick').getBoundingClientRect();
      const z = document.getElementById('joystickZone').getBoundingClientRect();
      return j.left >= z.left - 1 && j.right <= z.right + 1 &&
             j.top >= z.top - 1 && j.bottom <= z.bottom + 1;
    });

    console.log(`[${label}] shown:${shown} centerMatchesFall:${centerMatchesFall} dirOk:${dirOk}(${JSON.stringify(dir)}) inZone:${inZone}`);

    await page.mouse.up();
    await page.waitForTimeout(40);
    const hiddenAfter = await page.$eval('#joystick', el => getComputedStyle(el).display === 'none');
    console.log(`[${label}] hidden after release:${hiddenAfter}`);
    return { shown, centerMatchesFall, dirOk, inZone, hiddenAfter };
  }

  const r1 = await steerAndCheck('UP', 0, -50, { x: 0, y: -1 });
  const r2 = await steerAndCheck('LEFT', -50, 0, { x: -1, y: 0 });
  const r3 = await steerAndCheck('DOWN', 0, 50, { x: 0, y: 1 });
  const r4 = await steerAndCheck('RIGHT', 50, 0, { x: 1, y: 0 });

  console.log('console errors:', errors.length, errors.slice(0, 3));

  const pass =
    hiddenBefore && zoneBelowCanvas &&
    r1.shown && r1.centerMatchesFall && r1.dirOk && r1.inZone && r1.hiddenAfter &&
    r2.shown && r2.dirOk && r2.inZone && r2.hiddenAfter &&
    r3.shown && r3.dirOk && r3.inZone && r3.hiddenAfter &&
    r4.shown && r4.dirOk && r4.inZone && r4.hiddenAfter &&
    errors.length === 0;

  console.log(pass ? 'RESULT: PASS' : 'RESULT: FAIL');
  await browser.close();
  process.exit(pass ? 0 : 1);
})();
