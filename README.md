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

### 方式二：用 XcodeGen 重新生成工程（可选）

如果你安装了 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
cd SnakeGame
xcodegen generate
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
| 防掉头 | 不允许 180° 反方向掉头 |
| 速度递增 | 每吃一个食物移动速度加快，最低 60ms/tick |
| 最高分 | 使用 UserDefaults 持久化保存最高分 |
| 暂停/继续 | 右上角暂停按钮，支持随时暂停 |
| 视觉效果 | 蛇头蛇身渐变配色、食物发光脉冲、蛇头眼睛跟随方向 |
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

