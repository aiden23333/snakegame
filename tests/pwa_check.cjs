const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome' });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  const page = await ctx.newPage();

  const consoleErrors = [];
  page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('pageerror', e => consoleErrors.push('pageerror: ' + e.message));

  // ignore resource 404s for favicon specifically
  const netFail = [];
  page.on('requestfailed', r => { if (!r.url().endsWith('favicon.ico')) netFail.push(r.url() + ' ' + (r.failure() && r.failure().errorText)); });

  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'networkidle' });

  const results = [];
  const assert = (name, cond, extra='') => results.push({ name, pass: !!cond, extra });

  // 1. manifest reachable + valid JSON + key fields
  const manResp = await page.goto('http://localhost:8080/manifest.webmanifest');
  const manText = await manResp.text();
  let man = null; try { man = JSON.parse(manText); } catch(e) {}
  assert('manifest 可访问且是合法 JSON', man && man.name);
  assert('manifest display=standalone', man && man.display === 'standalone', man && man.display);
  assert('manifest 含 192 与 512 图标', man && man.icons && man.icons.some(i=>i.sizes==='192x192') && man.icons.some(i=>i.sizes==='512x512'));

  // back to page
  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'networkidle' });

  // 2. icons reachable
  for (const f of ['apple-touch-icon.png','icon-192.png','icon-512.png']) {
    const r = await page.goto('http://localhost:8080/'+f);
    assert('图标可访问 '+f, r.status() === 200, 'status '+r.status());
  }

  // 3. service worker registered
  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'load' });
  await page.waitForTimeout(1500);
  const swCount = await page.evaluate(async () => {
    if (!('serviceWorker' in navigator)) return -1;
    const regs = await navigator.serviceWorker.getRegistrations();
    return regs.length;
  });
  assert('Service Worker 已注册', swCount >= 1, 'regs='+swCount);

  // 4. page still has no console errors / net failures (besides favicon)
  assert('无 JS 控制台报错', consoleErrors.length === 0, consoleErrors.join(' | '));
  assert('无关键网络请求失败', netFail.length === 0, netFail.join(' | '));

  // 5. app still playable: start + score increment path
  await page.goto('http://localhost:8080/preview.html', { waitUntil: 'load' });
  const tapStart = await page.$('text=开始');
  if (tapStart) await tapStart.tap();
  await page.waitForTimeout(300);
  const st = await page.evaluate(() => window.__snake && window.__snake.state);
  assert('点击开始进入 playing', st && st.gameState === 'playing', st && st.gameState);

  await browser.close();

  let allPass = true;
  for (const r of results) {
    console.log((r.pass ? 'PASS ' : 'FAIL ') + r.name + (r.extra ? '  ['+r.extra+']' : ''));
    if (!r.pass) allPass = false;
  }
  console.log(allPass ? '\nALL PWA CHECKS PASSED' : '\nSOME CHECKS FAILED');
  process.exit(allPass ? 0 : 1);
})();
