# 贪食蛇 SnakeGame (iOS / SwiftUI)

一个使用 SwiftUI 原生开发的 iOS 贪食蛇游戏，支持滑动操控、计分系统、最高分记录、暂停/继续等功能。

## 项目结构

```
SnakeGame/
├── SnakeGame.xcodeproj/          # Xcode 工程文件（直接双击打开）
├── preview.html                  # 浏览器即时试玩版（手机端体验一致）
├── project.yml                   # XcodeGen 配置（可选）
├── SnakeGame/                    # Swift 源码目录
│   ├── SnakeGameApp.swift        # App 入口点（@main）
│   ├── ContentView.swift         # 主界面：游戏画板 + 滑动手势 + 状态遮罩
│   ├── GameModel.swift           # 数据模型：Direction / GameState / GridPoint
│   ├── GameViewModel.swift       # 游戏逻辑：移动、碰撞、食物、计分、Timer
│   ├── InfoPlistReference.swift  # Info.plist 参考配置
│   └── Assets.xcassets/          # 资源目录（AccentColor + AppIcon）
```

## 运行方式

### 方式一：直接用 Xcode 打开（推荐）

1. 双击 `SnakeGame.xcodeproj` 打开项目
2. 在 Xcode 左上角选择模拟器（如 iPhone 15）或真机
3. 按 `Cmd + R` 编译运行

> 首次打开如提示 "Trust" 开发者，选择 Trust 即可。

### 方式二：用 XcodeGen 生成工程（推荐，仓库未提交 .xcodeproj）

仓库只提交 `project.yml`，**不提交** `.xcodeproj`（它绑定本机路径，无法直接跨机器使用）。安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 后从配置重新生成：

```bash
brew install xcodegen        # 只需一次
xcodegen generate            # 读取仓库根目录 project.yml，生成 SnakeGame.xcodeproj
open SnakeGame.xcodeproj
```

### 方式三：新建项目后手动导入源码

1. 打开 Xcode → Create a new Xcode project → iOS → App
2. Product Name 填 `SnakeGame`，Interface 选 `SwiftUI`，Language 选 `Swift`
3. 创建后删除自动生成的 `ContentView.swift` 和 `SnakeGameApp.swift`
4. 将 `SnakeGame/` 目录下的 `.swift` 文件拖入项目
5. 按 `Cmd + R` 运行

## 浏览器试玩

直接用手机或电脑浏览器打开 `preview.html` 即可体验：

- 手机端：在画板上**上下左右滑动**控制方向
- 电脑端：使用 **方向键 / WASD**，空格暂停

## 游戏特性

| 特性 | 说明 |
|------|------|
| 滑动操控 | 上下左右滑动屏幕控制蛇的方向 |
| 浮动摇杆 | 底部触控区内按住任意位置即生成摇杆，**落点即圆心**，旋钮跟随手指 360° 滑动并按角度映射上下左右（中心死区已调小、灵敏度高）；松手即隐藏，平时完全不占空间、不遮挡棋盘；与全局滑动互不冲突 |
| 防掉头 | 不允许 180° 反方向掉头 |
| 速度递增 | 每吃一个食物移动速度加快，最低 60ms/tick |
| 最高分（分模式） | 按「难度 + 是否道具」分别记录最高分，各模式互不共用（iOS 存于 `SnakeBestScores`；网页存于 `snakeBestScores`），切换模式时展示值随之更新 |
| 暂停/继续 | 右上角暂停按钮，支持随时暂停 |
| 视觉效果 | 蛇头蛇身渐变配色、食物发光脉冲、蛇头眼睛跟随方向 |
| **丝滑移动** | 子格子插值渲染：两次 tick 之间平滑滑动，不再一格一顿（HTML 用插值系数；iOS 用 TimelineView + Canvas 插值） |
| 结束重选 | 游戏结束后可「选择模式」返回难度 / 道具选择界面，或「再来一局」以当前设置直接重开 |
| 状态管理 | ready → playing → paused / gameOver 完整状态机 |

## 技术规格

- **最低系统**: iOS 16.0+
- **框架**: SwiftUI + Combine
- **语言**: Swift 5.9+
- **设备**: 仅 iPhone（竖屏）
- **Canvas**: 使用 SwiftUI Canvas 高性能绘制游戏画面

## 操作说明

1. 点击「开始游戏」启动
2. 在画板区域**滑动**来改变蛇的移动方向
3. 吃到红色食物得 10 分，蛇身变长，速度加快
4. 撞墙或撞到自己则游戏结束
5. 暂停按钮可随时暂停/继续

## 路径 C：免签名安装（PWA，推荐给非开发者）

`preview.html` 已升级为 **PWA（渐进式 Web 应用）**，无需 Apple 开发者账号、无需签名，就能在 iPhone 上"像 App 一样"安装使用。

### 它满足了什么
- `apple-mobile-web-app-capable` + `manifest`（`display: standalone`）→ 从主屏幕打开时**无浏览器地址栏**，全屏运行
- `apple-touch-icon.png`（180px）+ `icon-192/512.png` → 主屏幕上的**正式图标**
- `sw.js` 离线 Service Worker → 首次加载后**断网也能玩**
- `favicon.ico` → 浏览器标签图标（消除 404）

### 安装到 iPhone 的步骤
1. 把整个 `SnakeGame/` 文件夹托管到任意静态空间（GitHub Pages / Vercel / Netlify，或公司内网服务器）
2. 用 iPhone 的 **Safari** 打开那个网址
3. 点底部**分享按钮** → **"添加到主屏幕"**
4. 主屏幕出现"贪食蛇"图标，点开即全屏运行，和原生 App 几乎一样

> 注意：iOS 的"添加到主屏幕"必须用 **Safari**，Chrome/微信内置浏览器不支持。
> localhost（本机 `http://localhost:8080`）仅供开发预览，给别人的链接必须是公网/内网可访问的 HTTPS 或 HTTP 地址。

### 相关文件
```
SnakeGame/
├── preview.html              # 游戏本体（单文件，含全部 CSS/JS）
├── manifest.webmanifest      # PWA 清单
├── sw.js                     # 离线 Service Worker
├── apple-touch-icon.png      # 主屏幕图标 180px
├── icon-192.png / icon-512.png  # 清单图标
└── favicon.ico
```

### 永久托管地址（GitHub Pages，推荐）
已部署到公开仓库 `aiden23333/snakegame`，GitHub Pages 状态 `built`：
```
https://aiden23333.github.io/snakegame/
```
iPhone 用 Safari 打开 → 分享 → 添加到主屏幕即可。二维码见 `SnakeGame/install_qr.png`（已指向该永久地址）。
> 注：本沙箱代理无法直连 github.io，故部署后无法从本机 curl 验证；GitHub API 查询 Pages 状态为 `built` 即确认已上线。

### 验证
`tests/pwa_check.cjs`（Playwright + 本机 Chrome）已通过：清单合法、`display=standalone`、三张图标可访问、Service Worker 注册成功、页面无控制台报错。

## 在另一台电脑上克隆、修改与重新部署

本仓库同时包含**网页版（PWA）**与**原生 iOS 工程**两份代码，clone 后即可在任意电脑继续改。

### 1. 克隆

```bash
git clone https://github.com/aiden23333/snakegame.git
cd snakegame
```

### 2. 仓库实际结构（注意：与本地开发目录略有不同）

```
snakegame/                  # 仓库根
├── index.html              # GitHub Pages 入口（= preview.html，内容一致）
├── preview.html            # 网页试玩版（单文件，含全部 CSS/JS）
├── manifest.webmanifest    # PWA 清单
├── sw.js                   # 离线 Service Worker
├── apple-touch-icon.png / icon-192.png / icon-512.png / favicon.ico
├── install_qr.png
├── project.yml             # XcodeGen 配置（用于重新生成 Xcode 工程）
├── SnakeGame/              # 原生 Swift 源码（见上「项目结构」）
└── tests/                  # Playwright 自动化测试
```

> 仓库**不提交** `.xcodeproj`（它依赖本机路径，且可由 `project.yml` 重新生成）。拿到仓库后用 XcodeGen 生成即可，见下。

### 3. 改网页版（preview.html）

直接编辑 `preview.html`（或 `index.html`，二者需保持一致）。本地预览：

```bash
python3 -m http.server 8080     # 然后浏览器打开 http://localhost:8080
```

### 4. 改原生 iOS 工程（Swift/SwiftUI）

```bash
brew install xcodegen            # 只需一次
xcodegen generate                # 读取仓库根目录 project.yml，生成 SnakeGame.xcodeproj
open SnakeGame.xcodeproj
```

- 源码都在 `SnakeGame/` 目录下，直接改 `.swift` 文件。
- 资源（图标等）在 `SnakeGame/Assets.xcassets/`。
- 编译运行：`Cmd + R`（选模拟器或真机）。
- 真机运行需用自己的 Apple ID 签名：Xcode → Signing & Capabilities → Team 选自己的账号。

### 5. 重新部署 / 推送到 GitHub Pages

无论改了网页还是源码，统一流程：

```bash
git add -A
git commit -m "你的改动说明"
git push origin main
```

推送后 GitHub Pages 会自动重新构建并上线到 `https://aiden23333.github.io/snakegame/`（通常 1 分钟内生效）。
可在仓库 **Settings → Pages** 查看构建状态。

### 6. 常见坑

- 网页版改了 `preview.html` **一定要同步 `index.html`**，否则本地预览和线上不一致（本仓库提交时 `preview.html` 会被同步覆盖到 `index.html`）。
- iOS 工程**不要手动提交 `.xcodeproj`**；改 `project.yml` 后重新 `xcodegen generate` 即可。
- "添加到主屏幕"必须用 **Safari**，Chrome / 微信内置浏览器不支持。

