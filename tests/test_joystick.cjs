const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome' });
  const page = await browser.newPage({ viewport: { width: 390, height: 780 } });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));

  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'networkidle' });
  await page.waitForSelector('#startBtn');

  // 摇杆元素存在且可见；并且位于画布下方（不遮挡主画面）
  const layout = await page.evaluate(() => {
    const j = document.getElementById('joystick').getBoundingClientRect();
    const c = document.getElementById('canvasWrap').getBoundingClientRect();
    return {
      joyVisible: j.width > 0 && j.height > 0,
      joyBottomInView: j.bottom <= window.innerHeight + 1,
      joyBelowCanvas: j.top >= c.bottom - 2, // 与画布相邻或在其下方，不重叠
    };
  });
  console.log('layout:', JSON.stringify(layout));

  // 开始游戏
  await page.click('#startBtn');
  await page.waitForTimeout(200);

  // 取摇杆中心
  const box = await page.$eval('#joystick', el => {
    const r = el.getBoundingClientRect();
    return { cx: r.left + r.width / 2, cy: r.top + r.height / 2 };
  });

  async function dragTo(dx, dy) {
    await page.mouse.move(box.cx, box.cy);
    await page.mouse.down();
    // 分步移动，确保 pointermove 连续触发
    const steps = 6;
    for (let i = 1; i <= steps; i++) {
      await page.mouse.move(box.cx + dx * i / steps, box.cy + dy * i / steps);
      await page.waitForTimeout(20);
    }
    const knob = await page.$eval('#joystickKnob', el => el.style.transform);
    await page.mouse.up();
    await page.waitForTimeout(120); // 等一个 tick 让方向生效
    const dir = await page.evaluate(() => window.__snake.state.direction);
    return { knob, dir };
  }

  const up = await dragTo(0, -50);
  console.log('拖到上:', JSON.stringify(up));
  const okUp = up.dir.x === 0 && up.dir.y === -1 && /translate/.test(up.knob);

  const right = await dragTo(50, 0);
  console.log('拖到右:', JSON.stringify(right));
  const okRight = right.dir.x === 1 && right.dir.y === 0;

  const down = await dragTo(0, 50);
  console.log('拖到下:', JSON.stringify(down));
  const okDown = down.dir.x === 0 && down.dir.y === 1;

  // 当前方向是下，向左不是掉头，应允许
  const left = await dragTo(-50, 0);
  console.log('拖到左:', JSON.stringify(left));
  const okLeft = left.dir.x === -1 && left.dir.y === 0;

  // 松手后旋钮应回中
  const knobAfter = await page.$eval('#joystickKnob', el => el.style.transform);
  console.log('松手后旋钮 transform:', knobAfter);
  const okReset = /translate\(0px,\s*0px\)/.test(knobAfter) || knobAfter === '' || knobAfter === 'translate(0px, 0px)';

  console.log('console errors:', errors.length, errors.slice(0, 3));
  const pass = layout.joyVisible && layout.joyBottomInView && layout.joyBelowCanvas
            && okUp && okRight && okDown && okLeft && okReset && errors.length === 0;
  console.log(pass ? 'RESULT: PASS' : 'RESULT: FAIL');
  await browser.close();
  process.exit(pass ? 0 : 1);
})();
