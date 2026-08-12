const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome' });
  const page = await browser.newPage({ viewport: { width: 390, height: 780 } });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));

  // 种子：easy_1=0（待测写入），normal_0=777（应不受影响）
  await page.addInitScript(() => {
    localStorage.clear();
    localStorage.setItem('snakeBestScores', JSON.stringify({ 'easy_1': 0, 'normal_0': 777 }));
  });

  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'networkidle' });
  await page.waitForSelector('#startBtn');
  // 切到「简单（穿墙）」避免撞墙误死，模式 = easy_1
  await page.click('#difficultySeg .seg-btn[data-diff="easy"]');
  await page.click('#startBtn');
  await page.click('body'); // 确保有焦点可接收键盘事件

  const deadline = Date.now() + 15000;
  let scored = false;
  while (Date.now() < deadline) {
    const r = await page.evaluate(() => {
      const st = window.__snake.state;
      if (st.gameState === 'gameOver') return { over: true, score: st.score, move: null };
      const head = st.snake[0], food = st.food, d = st.direction;
      const dx = food.x - head.x, dy = food.y - head.y;
      let nx = 0, ny = 0;
      if (Math.abs(dx) >= Math.abs(dy)) {
        if (dx !== 0 && !((dx < 0 && d.x > 0) || (dx > 0 && d.x < 0))) nx = dx > 0 ? 1 : -1;
        else if (dy !== 0) ny = dy > 0 ? 1 : -1;
      } else {
        if (dy !== 0 && !((dy < 0 && d.y > 0) || (dy > 0 && d.y < 0))) ny = dy > 0 ? 1 : -1;
        else if (dx !== 0) nx = dx > 0 ? 1 : -1;
      }
      let move = null;
      if (nx === 1) move = 'ArrowRight';
      else if (nx === -1) move = 'ArrowLeft';
      else if (ny === 1) move = 'ArrowDown';
      else if (ny === -1) move = 'ArrowUp';
      return { over: false, score: st.score, move };
    });
    if (r.score > 0) { scored = true; break; }
    if (r.over) break;
    if (r.move) await page.keyboard.press(r.move);
    await page.waitForTimeout(60);
  }
  console.log('在 easy_1 得分:', scored);

  const store = await page.evaluate(() => JSON.parse(localStorage.getItem('snakeBestScores')));
  console.log('写入后 bestScores:', JSON.stringify(store));
  const okWrite = (store['easy_1'] || 0) > 0;            // 只写到了 easy_1
  const okUnchanged = (store['normal_0'] || 0) === 777;  // normal_0 不受影响
  console.log('easy_1 已写入>0:', okWrite, '| normal_0 未变:', okUnchanged);
  console.log('console errors:', errors.length, errors.slice(0, 3));
  const pass = scored && okWrite && okUnchanged && errors.length === 0;
  console.log(pass ? 'RESULT: PASS' : 'RESULT: FAIL');
  await browser.close();
  process.exit(pass ? 0 : 1);
})();
