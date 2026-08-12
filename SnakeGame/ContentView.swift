import SwiftUI

// MARK: - ContentView

struct ContentView: View {

    @StateObject private var viewModel = GameViewModel()

    // 滑动手势记录的起点
    @State private var dragStart: CGPoint?

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [Color(hex: 0x1a1a2e), Color(hex: 0x16213e), Color(hex: 0x0f3460)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                // 顶栏：得分 + 最高分
                topBar

                // 状态徽标（连击 / 生效中的道具）
                statusRow

                // 游戏画板
                gameBoard

                // 底部提示
                controlHint
            }
            .padding(.horizontal, 16)

            // 暂停按钮（右上角浮动，仅游戏中显示）
            if viewModel.gameState == .playing || viewModel.gameState == .paused {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.togglePause()
                        }) {
                            Image(systemName: viewModel.gameState == .paused ? "play.fill" : "pause.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: 0x64ffda))
                                .frame(width: 38, height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: 0x64ffda).opacity(0.15), lineWidth: 1)
                                )
                                .background(Color(hex: 0x64ffda).opacity(0.05))
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        }
        .gesture(swipeGesture)
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack {
            // 当前得分
            VStack(alignment: .leading, spacing: 2) {
                Text("得分")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: 0x8892b0))
                    .tracking(1)
                Text("\(viewModel.score)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: 0x64ffda))
            }

            Spacer()

            // 最高分
            VStack(alignment: .trailing, spacing: 2) {
                Text("最高分")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: 0x8892b0))
                    .tracking(1)
                Text("\(viewModel.highScore)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: 0xffb86c))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 状态徽标（连击 / 道具效果）

    @ViewBuilder
    private var statusRow: some View {
        if viewModel.gameState == .playing {
            HStack(spacing: 8) {
                if viewModel.combo >= 2 {
                    Text("连击 x\(viewModel.combo)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: 0xffb86c))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: 0xffb86c).opacity(0.15)))
                }
                if viewModel.speedState == .fast {
                    badge("🔥 加速", color: 0xff6b35)
                }
                if viewModel.speedState == .slow {
                    badge("🐢 减速", color: 0x4ade80)
                }
                if viewModel.ghostActive {
                    badge("👻 幽灵", color: 0xa78bfa)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 22)
        } else {
            EmptyView()
        }
    }

    private func badge(_ text: String, color: UInt32) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color(hex: color))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(hex: color).opacity(0.15)))
    }

    // MARK: - 游戏画板

    private var gameBoard: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / CGFloat(GameViewModel.gridSize)

            ZStack {
                // 画板背景
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: 0x0d1117))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

                // 蛇、食物、障碍、道具、粒子
                TimelineView(AnimationTimelineSchedule(minimumInterval: 1.0/60.0)) { _ in
                    Canvas { context, _ in
                        drawGrid(context: context, cell: cell, size: size)
                        drawObstacles(context: context, cell: cell)
                        drawFood(context: context, cell: cell)
                        drawPowerUp(context: context, cell: cell)
                        drawSnake(context: context, cell: cell)
                        drawParticles(context: context, cell: cell)
                    }
                    .frame(width: size, height: size)
                }

                // 状态遮罩
                overlayView
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - 滑动手势

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = value.startLocation
                }
            }
            .onEnded { value in
                // 仅在游戏进行中响应滑动转向，避免与开始/暂停/结束按钮冲突
                guard viewModel.gameState == .playing else { dragStart = nil; return }
                guard let start = dragStart else { return }
                let dx = value.location.x - start.x
                let dy = value.location.y - start.y
                let absDx = abs(dx)
                let absDy = abs(dy)

                // 最小滑动距离
                guard absDx > 20 || absDy > 20 else {
                    dragStart = nil
                    return
                }

                if absDx > absDy {
                    viewModel.changeDirection(dx > 0 ? .right : .left)
                } else {
                    viewModel.changeDirection(dy > 0 ? .down : .up)
                }
                dragStart = nil
            }
    }

    // MARK: - Canvas 绘制

    private func drawGrid(context: GraphicsContext, cell: CGFloat, size: CGFloat) {
        var path = Path()
        for i in 0...GameViewModel.gridSize {
            let pos = CGFloat(i) * cell
            path.move(to: CGPoint(x: pos, y: 0))
            path.addLine(to: CGPoint(x: pos, y: size))
            path.move(to: CGPoint(x: 0, y: pos))
            path.addLine(to: CGPoint(x: size, y: pos))
        }
        context.stroke(path, with: .color(Color(hex: 0x64ffda).opacity(0.03)), lineWidth: 0.5)
    }

    private func drawObstacles(context: GraphicsContext, cell: CGFloat) {
        for obs in viewModel.obstacles {
            let rect = CGRect(
                x: CGFloat(obs.x) * cell + cell * 0.06,
                y: CGFloat(obs.y) * cell + cell * 0.06,
                width: cell * 0.88,
                height: cell * 0.88
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: cell * 0.2),
                with: .color(Color(hex: 0x2b2f44))
            )
        }
    }

    private func drawFood(context: GraphicsContext, cell: CGFloat) {
        // SwiftUI Canvas 闭包中的 context 是 let 常量，需先创建可变副本再修改 opacity
        var context = context
        let fx = CGFloat(viewModel.food.x) * cell + cell / 2
        let fy = CGFloat(viewModel.food.y) * cell + cell / 2
        let r = cell * 0.32

        // 外发光
        let glowRect = CGRect(x: fx - cell, y: fy - cell, width: cell * 2, height: cell * 2)
        context.opacity = 0.3
        context.fill(
            Path(ellipseIn: glowRect),
            with: .color(Color(hex: 0xff6b6b))
        )
        context.opacity = 1.0

        // 食物本体
        context.fill(
            Path(ellipseIn: CGRect(x: fx - r, y: fy - r, width: r * 2, height: r * 2)),
            with: .color(Color(hex: 0xff6b6b))
        )
    }

    private func drawPowerUp(context: GraphicsContext, cell: CGFloat) {
        guard let pu = viewModel.powerUp else { return }
        // SwiftUI Canvas 闭包中的 context 是 let 常量
        var context = context
        let px = CGFloat(pu.position.x) * cell + cell / 2
        let py = CGFloat(pu.position.y) * cell + cell / 2

        let glowRect = CGRect(x: px - cell, y: py - cell, width: cell * 2, height: cell * 2)
        context.opacity = 0.35
        context.fill(Path(ellipseIn: glowRect), with: .color(Color(hex: pu.type.color)))
        context.opacity = 1.0

        let r = cell * 0.36
        context.fill(
            Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
            with: .color(Color(hex: pu.type.color))
        )

        // emoji 图标居中
        context.draw(
            Text(pu.type.emoji).font(.system(size: cell * 0.5)),
            at: CGPoint(x: px, y: py),
            anchor: .center
        )
    }

    private func drawSnake(context: GraphicsContext, cell: CGFloat) {
        let pad = cell * 0.08
        let radius = cell * 0.25
        let t = viewModel.interpolationFactor()
        let n = viewModel.snake.count
        guard n > 0 else { return }

        // 插值后的每段中心（格坐标为单位）：在 prev→cur 之间平滑滑动
        var ix = [CGFloat](repeating: 0, count: n)
        var iy = [CGFloat](repeating: 0, count: n)
        for i in 0..<n {
            let cur = viewModel.snake[i]
            let prev = (i < viewModel.prevSnake.count) ? viewModel.prevSnake[i] : cur
            var dx = cur.x - prev.x
            var dy = cur.y - prev.y
            if abs(dx) > 1 { dx = 0 }  // 穿墙瞬间吸附，避免跨屏滑动
            if abs(dy) > 1 { dy = 0 }
            ix[i] = CGFloat(prev.x) + CGFloat(dx) * t
            iy[i] = CGFloat(prev.y) + CGFloat(dy) * t
        }

        // 从尾到头绘制
        for i in (0..<n).reversed() {
            let cx = ix[i] * cell
            let cy = iy[i] * cell
            let rect = CGRect(
                x: cx + pad,
                y: cy + pad,
                width: cell - pad * 2,
                height: cell - pad * 2
            )
            let path = Path(roundedRect: rect, cornerRadius: radius)

            if i == 0 {
                // 蛇头
                let headColor: Color = viewModel.ghostActive ? Color(hex: 0xa78bfa) : Color(hex: 0x64ffda)
                context.fill(path, with: .color(headColor))
                let center = CGPoint(x: cx + cell / 2, y: cy + cell / 2)
                drawEyes(context: context, center: center, cell: cell, dir: viewModel.direction)
            } else {
                // 蛇身：从头的青色渐变到尾的深青
                let f = Double(i) / Double(n)
                let color = Color(
                    red: 0.18 + (0.42 - 0.18) * (1 - f),
                    green: 0.82 + (0.62 - 0.82) * (1 - f),
                    blue: 0.80 + (0.56 - 0.80) * (1 - f)
                )
                context.fill(path, with: .color(color))
            }
        }
    }

    private func drawParticles(context: GraphicsContext, cell: CGFloat) {
        for p in viewModel.particles {
            let cx = CGFloat(p.x) * cell
            let cy = CGFloat(p.y) * cell
            let r = CGFloat(p.size) * cell * 0.5
            context.fill(
                Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                with: .color(Color(hex: p.color).opacity(max(0, p.life)))
            )
        }
    }

    private func drawEyes(context: GraphicsContext, center: CGPoint, cell: CGFloat, dir: Direction) {
        let cx = center.x
        let cy = center.y
        let eyeR = cell * 0.07
        let offset = cell * 0.18

        var e1, e2: CGPoint
        switch dir {
        case .right:
            e1 = CGPoint(x: cx + offset, y: cy - offset)
            e2 = CGPoint(x: cx + offset, y: cy + offset)
        case .left:
            e1 = CGPoint(x: cx - offset, y: cy - offset)
            e2 = CGPoint(x: cx - offset, y: cy + offset)
        case .down:
            e1 = CGPoint(x: cx - offset, y: cy + offset)
            e2 = CGPoint(x: cx + offset, y: cy + offset)
        case .up:
            e1 = CGPoint(x: cx - offset, y: cy - offset)
            e2 = CGPoint(x: cx + offset, y: cy - offset)
        }

        context.fill(
            Path(ellipseIn: CGRect(x: e1.x - eyeR, y: e1.y - eyeR, width: eyeR * 2, height: eyeR * 2)),
            with: .color(Color(hex: 0x0d1117))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: e2.x - eyeR, y: e2.y - eyeR, width: eyeR * 2, height: eyeR * 2)),
            with: .color(Color(hex: 0x0d1117))
        )
    }

    // MARK: - 状态遮罩

    @ViewBuilder private var overlayView: some View {
        switch viewModel.gameState {
        case .ready:
            startPanel
        case .paused:
            overlayPanel(
                title: "已暂停",
                titleGradient: [Color(hex: 0x64ffda), Color(hex: 0x48d1cc)],
                subtitle: "",
                buttonTitle: "继续",
                action: { viewModel.togglePause() }
            )
        case .gameOver:
            overlayPanel(
                title: "游戏结束",
                titleGradient: [Color(hex: 0xff6b6b), Color(hex: 0xffb86c)],
                subtitle: "得分  \(viewModel.score)",
                buttonTitle: "再来一局",
                action: { viewModel.startGame() }
            )
        case .playing:
            EmptyView()
        }
    }

    // MARK: - 开始界面（含难度选择 + 道具开关）

    private var startPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: 0x0d1117).opacity(0.92))
                .background(.ultraThinMaterial.opacity(0.3))

            VStack(spacing: 18) {
                Text("贪食蛇")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0x64ffda), Color(hex: 0xffb86c)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("滑动屏幕控制方向 · 吃食物得分")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0x8892b0))

                // 难度选择
                VStack(spacing: 8) {
                    Text("难度")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: 0x8892b0))
                    HStack(spacing: 10) {
                        ForEach(Difficulty.allCases, id: \.self) { d in
                            Button(action: { viewModel.setDifficulty(d) }) {
                                VStack(spacing: 2) {
                                    Text(d.title)
                                        .font(.system(size: 15, weight: .bold))
                                    Text(d.subtitle)
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: 0x636e8e))
                                }
                                .foregroundColor(viewModel.difficulty == d ? Color(hex: 0x0d1117) : Color(hex: 0x64ffda))
                                .frame(width: 84, height: 50)
                                .background(
                                    Capsule()
                                        .fill(viewModel.difficulty == d
                                              ? Color(hex: 0x64ffda)
                                              : Color(hex: 0x64ffda).opacity(0.08))
                                )
                            }
                        }
                    }
                }

                // 道具模式开关
                HStack(spacing: 10) {
                    Text("道具模式")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: 0x8892b0))
                    Button(action: { viewModel.setPowerUpMode(!viewModel.powerUpMode) }) {
                        Text(viewModel.powerUpMode ? "开" : "关")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(viewModel.powerUpMode ? Color(hex: 0x0d1117) : Color(hex: 0xffb86c))
                            .frame(width: 56, height: 34)
                            .background(
                                Capsule()
                                    .fill(viewModel.powerUpMode
                                          ? Color(hex: 0x64ffda)
                                          : Color(hex: 0xffb86c).opacity(0.15))
                            )
                    }
                }

                Button(action: { viewModel.startGame() }) {
                    Text("开始游戏")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: 0x0d1117))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0x64ffda), Color(hex: 0x48d1cc)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: Color(hex: 0x64ffda).opacity(0.3), radius: 10)
                }
                .padding(.top, 6)
            }
            .padding(24)
        }
    }

    private func overlayPanel(
        title: String,
        titleGradient: [Color],
        subtitle: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: 0x0d1117).opacity(0.88))
                .background(.ultraThinMaterial.opacity(0.3))

            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: titleGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x8892b0))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: 0x0d1117))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0x64ffda), Color(hex: 0x48d1cc)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: Color(hex: 0x64ffda).opacity(0.3), radius: 10)
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - 底部提示

    private var controlHint: some View {
        Text("👆 上下左右滑动屏幕 👆")
            .font(.system(size: 13))
            .foregroundColor(Color(hex: 0x636e8e))
    }
}

// MARK: - Color Hex 扩展

extension Color {
    init(hex value: UInt32) {
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0,
            opacity: 1
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
