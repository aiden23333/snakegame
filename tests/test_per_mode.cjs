const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome' });
  const page = await browser.newPage({ viewport: { width: 390, height: 780 } });
  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));

  // 在页面脚本运行前注入种子数据：普通+道具=120，简单+无道具=45
  await page.addInitScript(() => {
    localStorage.clear();
    localStorage.setItem('snakeBestScores', JSON.stringify({ 'normal_1': 120, 'easy_0': 45 }));
  });

  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'networkidle' });
  await page.waitForSelector('#startBtn');

  // 默认模式 = normal + 道具开 => 'normal_1' => 120
  let st = await page.evaluate(() => window.__snake.state);
  console.log('默认模式:', st.mode, '| 最高分:', st.highScore, '| bestScores:', JSON.stringify(st.bestScores));
  const ok1 = st.mode === 'normal_1' && st.highScore === 120;

  // 切到 简单（道具仍开）=> 'easy_1' => 无记录 => 0
  await page.click('#difficultySeg .seg-btn[data-diff="easy"]');
  st = await page.evaluate(() => window.__snake.state);
  console.log('切到简单(道具开):', st.mode, '| 最高分:', st.highScore);
  const ok2 = st.mode === 'easy_1' && st.highScore === 0;

  // 关道具 => 'easy_0' => 45
  await page.click('#powerToggle');
  st = await page.evaluate(() => window.__snake.state);
  console.log('关道具:', st.mode, '| 最高分:', st.highScore);
  const ok3 = st.mode === 'easy_0' && st.highScore === 45;

  // 回到 普通 + 道具开 => 'normal_1' => 120
  await page.click('#difficultySeg .seg-btn[data-diff="normal"]');
  await page.click('#powerToggle');
  st = await page.evaluate(() => window.__snake.state);
  console.log('回到 normal_1:', st.mode, '| 最高分:', st.highScore);
  const ok4 = st.mode === 'normal_1' && st.highScore === 120;

  // 展示元素与状态一致
  const disp = await page.$eval('#highScore', el => el.textContent);
  const ok5 = parseInt(disp, 10) === 120;

  console.log('console errors:', errors.length, errors.slice(0, 3));
  const pass = ok1 && ok2 && ok3 && ok4 && ok5 && errors.length === 0;
  console.log(pass ? 'RESULT: PASS' : 'RESULT: FAIL');
  await browser.close();
  process.exit(pass ? 0 : 1);
})();
