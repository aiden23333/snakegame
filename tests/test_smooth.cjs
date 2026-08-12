const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome' });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });

  const errors = [];
  page.on('console', m => {
    if (m.type() === 'error' && !/favicon\.ico/.test(m.text())) errors.push(m.text());
  });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));

  const results = [];
  const assert = (name, cond) => results.push((cond ? 'PASS ' : 'FAIL ') + name);

  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(300);

  // start game
  await page.click('#startBtn');
  await page.waitForTimeout(200);

  const s1 = await page.evaluate(() => window.__snake.state);
  assert('game started -> playing', s1.gameState === 'playing');

  // sample head pixel position twice ~60ms apart to confirm smooth (sub-cell) motion exists
  async function headPixel() {
    return await page.evaluate(() => {
      const c = document.getElementById('game');
      const ctx = c.getContext('2d');
      const img = ctx.getImageData(0, 0, c.width, c.height).data;
      // scan for the snake-head cyan-ish pixel (bright teal) and return centroid
      let sx = 0, sy = 0, n = 0;
      const w = c.width, h = c.height;
      for (let y = 0; y < h; y += 3) {
        for (let x = 0; x < w; x += 3) {
          const i = (y * w + x) * 4;
          const r = img[i], g = img[i + 1], b = img[i + 2];
          if (g > 180 && b > 150 && r < 140 && g > b) { sx += x; sy += y; n++; }
        }
      }
      return n ? { x: sx / n, y: sy / n, n } : null;
    });
  }

  const p1 = await headPixel();
  await page.waitForTimeout(70);
  const p2 = await headPixel();
  assert('snake rendered on canvas', !!p1 && p1.n > 20);
  if (p1 && p2) {
    const d = Math.hypot(p2.x - p1.x, p2.y - p1.y);
    // sub-cell smooth motion: between two samples the head should move less than a full cell
    // (a full cell is ~ width/17 px). If it were grid-snapping, delta would be 0 most frames.
    assert('smooth sub-cell motion present (head moved, <1 cell/frame)', d > 0.5 && d < (390 / 17));
  }

  // verify grid logic still advances over ~1.5s (state changes)
  const headA = s1.snake[0];
  await page.waitForTimeout(1500);
  const s2 = await page.evaluate(() => window.__snake.state);
  // 默认普通模式蛇直行会撞墙而结束，这是正确行为；只要不是崩溃（停留在 ready）即可
  assert('no crash (playing or gameOver)', s2.gameState === 'playing' || s2.gameState === 'gameOver');
  const moved = headA.x !== s2.snake[0].x || headA.y !== s2.snake[0].y || s2.score > s1.score;
  assert('snake advanced / scored over time', moved);

  await page.screenshot({ path: 'tests/smooth_gameplay.png' });
  assert('no console errors', errors.length === 0);

  console.log(results.join('\n'));
  if (errors.length) console.log('ERRORS:\n' + errors.join('\n'));
  const failed = results.filter(r => r.startsWith('FAIL')).length;
  console.log(failed === 0 ? '\nALL PASS' : `\n${failed} FAILED`);

  await browser.close();
  process.exit(failed === 0 ? 0 : 1);
})();
