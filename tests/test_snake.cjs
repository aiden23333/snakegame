/* eslint-disable */
// 贪食蛇浏览器自动化测试（Playwright + 本机 Chrome）
// 运行：NODE_PATH=<node workspace>/node_modules node tests/test_snake.cjs
const { chromium } = require('playwright');

const URL = 'http://localhost:8080/preview.html';
const TICK = 160; // 略大于游戏 tick(130ms)，等待一帧

let pass = 0, fail = 0;
const results = [];
function check(name, cond, extra) {
    if (cond) { pass++; results.push(`  ✅ ${name}`); }
    else { fail++; results.push(`  ❌ ${name}${extra ? ' — ' + extra : ''}`); }
}

(async () => {
    const browser = await chromium.launch({
        channel: 'chrome',
        headless: true,
        args: ['--no-sandbox'],
    });
    const page = await browser.newPage({ viewport: { width: 390, height: 844 } });

    const consoleErrors = [];
    page.on('console', m => {
        // 忽略浏览器自动请求 favicon.ico 等资源 404（非 JS 错误）
        if (m.type() === 'error' && !/Failed to load resource/i.test(m.text())) {
            consoleErrors.push(m.text());
        }
    });
    page.on('pageerror', e => consoleErrors.push('pageerror: ' + e.message));

    await page.goto(URL, { waitUntil: 'networkidle' });
    await page.waitForFunction(() => !!window.__snake);

    // ---------- 1. 初始状态 ----------
    let s = await page.evaluate(() => window.__snake.state);
    check('页面加载且测试钩子可用', !!s);
    check('初始 gameState = ready', s.gameState === 'ready', s.gameState);

    // ---------- 2. 开始游戏 ----------
    await page.click('#startBtn');
    await page.waitForTimeout(120);
    s = await page.evaluate(() => window.__snake.state);
    check('点击开始后 gameState = playing', s.gameState === 'playing', s.gameState);
    check('开始后 score = 0', s.score === 0, 'score=' + s.score);
    const startOverlayHidden = await page.evaluate(() =>
        document.getElementById('startOverlay').classList.contains('hidden'));
    check('开始遮罩已隐藏', startOverlayHidden);

    // ---------- 3. 防掉头（不能 180° 反向）----------
    // 蛇初始向右(x:1)。按左方向键应被忽略。
    await page.keyboard.press('ArrowLeft');
    await page.waitForTimeout(TICK);
    s = await page.evaluate(() => window.__snake.state);
    check('向右时按左不会被反向（direction.x 仍为 1）', s.direction.x === 1, JSON.stringify(s.direction));

    // ---------- 4. 正常转向 ----------
    // 向右时按上，应变为向上(y:-1)
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(TICK);
    s = await page.evaluate(() => window.__snake.state);
    check('向右时按上 → direction.y = -1', s.direction.y === -1, JSON.stringify(s.direction));

    // ---------- 5. 屏幕任意位置滑动转向（document 级 touch 监听）----------
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForFunction(() => !!window.__snake);
    await page.click('#startBtn');
    await page.waitForTimeout(120);
    // 当前向右。在 document 上派发一次“向上滑动”的触摸事件（起点与移动点都在画板之外也可）
    await page.evaluate(() => {
        const mk = (type, x1, y1, x2, y2) => {
            const t = (x, y) => new Touch({ identifier: 1, target: document.body, clientX: x, clientY: y });
            const ev = new TouchEvent(type, {
                cancelable: true, bubbles: true,
                touches: type === 'touchstart' ? [t(x1, y1)] : [t(x2, y2)],
                targetTouches: type === 'touchstart' ? [t(x1, y1)] : [t(x2, y2)],
                changedTouches: type === 'touchstart' ? [t(x1, y1)] : [t(x2, y2)],
            });
            document.dispatchEvent(ev);
        };
        mk('touchstart', 300, 400, 300, 400);
        mk('touchmove', 300, 400, 300, 280); // 向上滑动
    });
    await page.waitForTimeout(TICK);
    s = await page.evaluate(() => window.__snake.state);
    check('在 document 任意位置向上滑动 → direction.y = -1', s.direction.y === -1, JSON.stringify(s.direction));

    // ---------- 6. 吃食物计分（贪心导航，空棋盘必能吃到第一颗）----------
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForFunction(() => !!window.__snake);
    await page.click('#startBtn');
    await page.waitForTimeout(120);

    const keyFor = (d) => ({
        right: 'ArrowRight', left: 'ArrowLeft', up: 'ArrowUp', down: 'ArrowDown',
    }[d]);

    let ateScore = 0;
    for (let i = 0; i < 60; i++) {
        s = await page.evaluate(() => window.__snake.state);
        if (s.gameState === 'gameOver') break;
        if (s.score >= 10) { ateScore = s.score; break; }
        const head = s.snake[0];
        const food = s.food;
        const cur = s.direction;
        // 候选方向（去掉反向）
        const cands = [
            { d: 'right', p: { x: head.x + 1, y: head.y } },
            { d: 'left',  p: { x: head.x - 1, y: head.y } },
            { d: 'up',    p: { x: head.x, y: head.y - 1 } },
            { d: 'down',  p: { x: head.x, y: head.y + 1 } },
        ].filter(c => {
            if (c.d === 'left'  && cur.x === 1) return false;
            if (c.d === 'right' && cur.x === -1) return false;
            if (c.d === 'up'    && cur.y === 1) return false;
            if (c.d === 'down'  && cur.y === -1) return false;
            return c.p.x >= 0 && c.p.x < s.gridSize && c.p.y >= 0 && c.p.y < s.gridSize;
        });
        // 选能最小化到食物曼哈顿距离的方向
        cands.sort((a, b) =>
            (Math.abs(a.p.x - food.x) + Math.abs(a.p.y - food.y)) -
            (Math.abs(b.p.x - food.x) + Math.abs(b.p.y - food.y)));
        await page.keyboard.press(keyFor(cands[0].d));
        await page.waitForTimeout(TICK);
    }
    check('贪心导航可吃到食物，score ≥ 10', ateScore >= 10, 'score=' + ateScore);

    // ---------- 7. 撞墙游戏结束 ----------
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForFunction(() => !!window.__snake);
    await page.click('#startBtn');
    await page.waitForTimeout(3500); // 不转向，向右直行撞右墙
    s = await page.evaluate(() => window.__snake.state);
    const goVisible = await page.evaluate(() =>
        !document.getElementById('gameOverOverlay').classList.contains('hidden'));
    check('直行撞墙后 gameState = gameOver', s.gameState === 'gameOver', s.gameState);
    check('游戏结束遮罩显示', goVisible);

    // ---------- 8. 重新开始后归零 ----------
    await page.click('#restartBtn');
    await page.waitForTimeout(150);
    s = await page.evaluate(() => window.__snake.state);
    check('点击“再来一局”后 score 归 0', s.score === 0, 'score=' + s.score);
    check('重开后 gameState = playing', s.gameState === 'playing', s.gameState);

    // ---------- 截图 ----------
    await page.screenshot({ path: require('path').resolve(__dirname, '../tests/snake_test.png') });

    // ---------- 控制台报错 ----------
    check('运行期间无 JS 控制台报错', consoleErrors.length === 0, consoleErrors.join(' | '));

    await browser.close();

    console.log('\n==== 贪食蛇自动化测试报告 ====');
    results.forEach(r => console.log(r));
    console.log(`\n通过 ${pass} / 失败 ${fail}`);
    process.exit(fail === 0 ? 0 : 1);
})().catch(e => { console.error('测试脚本异常:', e); process.exit(2); });
