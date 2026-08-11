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

            VStack(spacing: 16) {
                // 顶栏：得分 + 最高分
                topBar

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

                // 蛇和食物
                Canvas { context, _ in
                    drawGrid(context: context, cell: cell, size: size)
                    drawFood(context: context, cell: cell)
                    drawSnake(context: context, cell: cell)
                }
                .frame(width: size, height: size)

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

    private func drawSnake(context: GraphicsContext, cell: CGFloat) {
        let pad = cell * 0.08
        let radius = cell * 0.25

        // 从尾到头绘制
        for i in (0..<viewModel.snake.count).reversed() {
            let seg = viewModel.snake[i]
            let rect = CGRect(
                x: CGFloat(seg.x) * cell + pad,
                y: CGFloat(seg.y) * cell + pad,
                width: cell - pad * 2,
                height: cell - pad * 2
            )
            let path = Path(roundedRect: rect, cornerRadius: radius)

            if i == 0 {
                // 蛇头
                context.fill(path, with: .color(Color(hex: 0x64ffda)))
                drawEyes(context: context, head: seg, cell: cell, dir: viewModel.direction)
            } else {
                // 蛇身：从头的青色渐变到尾的深青
                let t = Double(i) / Double(viewModel.snake.count)
                let color = Color(
                    red: 0.18 + (0.42 - 0.18) * (1 - t),
                    green: 0.82 + (0.62 - 0.82) * (1 - t),
                    blue: 0.80 + (0.56 - 0.80) * (1 - t)
                )
                context.fill(path, with: .color(color))
            }
        }
    }

    private func drawEyes(context: GraphicsContext, head: GridPoint, cell: CGFloat, dir: Direction) {
        let cx = CGFloat(head.x) * cell + cell / 2
        let cy = CGFloat(head.y) * cell + cell / 2
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
            overlayPanel(
                title: "贪食蛇",
                titleGradient: [Color(hex: 0x64ffda), Color(hex: 0xffb86c)],
                subtitle: "滑动屏幕控制方向\n吃掉食物，不要撞墙或自己",
                buttonTitle: "开始游戏",
                action: { viewModel.startGame() }
            )
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
