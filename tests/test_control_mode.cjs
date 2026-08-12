const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome' });
  const page = await browser.newPage({ viewport: { width: 390, height: 780 }, hasTouch: true });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));

  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'networkidle' });
  await page.waitForSelector('#startBtn');

  // 默认：按键模式 active，D-pad 可见，摇杆区隐藏
  const def = await page.evaluate(() => {
    const bc = document.getElementById('bottomControls');
    const ctrlActive = document.querySelector('#controlSeg .ctrl-seg-btn.active')?.dataset.ctrl;
    const dpad = document.getElementById('dpad');
    const zone = document.getElementById('joystickZone');
    return {
      ctrlActive,
      dpadVisible: getComputedStyle(dpad).display !== 'none',
      zoneHidden: getComputedStyle(zone).display === 'none',
      localStorage: localStorage.getItem('snakeControlMode'),
    };
  });
  console.log('default:', JSON.stringify(def));

  // 选 easy 穿墙，开始游戏
  await page.click('.seg-btn[data-diff="easy"]');
  await page.click('#startBtn');
  await page.waitForTimeout(200);

  // D-pad 按钮改方向（按键模式）：点击「上」
  await page.click('.dpad-btn[data-dir="up"]');
  await page.waitForTimeout(260);
  const dirUp = await page.evaluate(() => window.__snake.state.direction);
  console.log('dpad up -> dir:', JSON.stringify(dirUp));

  // 屏幕滑动在按键模式仍可用（合成 touch 事件）
  const swipeOkButtons = await page.evaluate(() => {
    const r = document.getElementById('game').getBoundingClientRect();
    const x0 = r.left + r.width/2, y0 = r.top + r.height/2;
    function mk(type, x, y) {
      const t = new Touch({ identifier: 1, target: document.body, clientX: x, clientY: y });
      const ev = new TouchEvent(type, { cancelable: true, bubbles: true, touches: type==='touchend'?[]:[t], targetTouches: type==='touchend'?[]:[t], changedTouches: [t] });
      document.dispatchEvent(ev);
    }
    mk('touchstart', x0, y0);
    mk('touchmove', x0 - 60, y0); // 向左滑
    mk('touchend', x0 - 60, y0);
    return true;
  });
  await page.waitForTimeout(260);
  const dirSwipeButtons = await page.evaluate(() => window.__snake.state.direction);
  console.log('swipe(left) in buttons mode -> dir:', JSON.stringify(dirSwipeButtons));

  // 切换到滑块模式
  // 先回开始界面（通过模式选择按钮不可直接，这里用 pause? 简化为重新加载并预设 localStorage）
  await page.evaluate(() => { localStorage.setItem('snakeControlMode', 'joystick'); });
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForSelector('#startBtn');
  const afterSwitch = await page.evaluate(() => {
    const ctrlActive = document.querySelector('#controlSeg .ctrl-seg-btn.active')?.dataset.ctrl;
    const dpadHidden = getComputedStyle(document.getElementById('dpad')).display === 'none';
    const zoneVisible = getComputedStyle(document.getElementById('joystickZone')).display !== 'none';
    return { ctrlActive, dpadHidden, zoneVisible };
  });
  console.log('after switch to joystick:', JSON.stringify(afterSwitch));

  // 滑块模式下浮动摇杆仍工作
  await page.click('.seg-btn[data-diff="easy"]');
  await page.click('#startBtn');
  await page.waitForTimeout(200);
  const layout = await page.evaluate(() => {
    const zr = document.getElementById('joystickZone').getBoundingClientRect();
    return { zrLeft: zr.left, zrRight: zr.right, zrTop: zr.top, zrBottom: zr.bottom };
  });
  const fallX = Math.round((layout.zrLeft + layout.zrRight)/2);
  const fallY = Math.round((layout.zrTop + layout.zrBottom)/2);
  await page.mouse.move(fallX, fallY);
  await page.mouse.down();
  const shown = await page.$eval('#joystick', el => getComputedStyle(el).display !== 'none');
  await page.mouse.move(fallX, fallY - 50); // 向上
  await page.waitForTimeout(260);
  const dirJoy = await page.evaluate(() => window.__snake.state.direction);
  await page.mouse.up();
  console.log('joystick up -> shown:', shown, 'dir:', JSON.stringify(dirJoy));

  // 滑块模式下屏幕滑动仍可用（在摇杆区外，如画布上滑动；注意避开反向被拦截）
  const swipeOkJoystick = await page.evaluate(() => {
    const r = document.getElementById('game').getBoundingClientRect();
    const x0 = r.left + r.width/2, y0 = r.top + r.height/2;
    function mk(type, x, y) {
      const t = new Touch({ identifier: 2, target: document.body, clientX: x, clientY: y });
      const ev = new TouchEvent(type, { cancelable: true, bubbles: true, touches: type==='touchend'?[]:[t], targetTouches: type==='touchend'?[]:[t], changedTouches: [t] });
      document.dispatchEvent(ev);
    }
    mk('touchstart', x0, y0);
    mk('touchmove', x0 + 60, y0); // 向右滑（相对当前 up 为非反向，可被接受）
    mk('touchend', x0 + 60, y0);
    return true;
  });
  await page.waitForTimeout(260);
  const dirSwipeJoy = await page.evaluate(() => window.__snake.state.direction);
  console.log('swipe(right) in joystick mode -> dir:', JSON.stringify(dirSwipeJoy));

  console.log('console errors:', errors.length, errors.slice(0,3));

  const pass =
    def.ctrlActive === 'buttons' && def.dpadVisible && def.zoneHidden &&
    def.localStorage === 'buttons' &&
    dirUp.x === 0 && dirUp.y === -1 &&
    dirSwipeButtons.x === -1 && dirSwipeButtons.y === 0 &&
    afterSwitch.ctrlActive === 'joystick' && afterSwitch.dpadHidden && afterSwitch.zoneVisible &&
    shown && dirJoy.x === 0 && dirJoy.y === -1 &&
    dirSwipeJoy.x === 1 && dirSwipeJoy.y === 0 &&
    errors.length === 0;

  console.log(pass ? 'RESULT: PASS' : 'RESULT: FAIL');
  await browser.close();
  process.exit(pass ? 0 : 1);
})();
