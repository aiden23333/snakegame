import Foundation
import SwiftUI
import Combine

// MARK: - GameViewModel

/// 贪食蛇游戏逻辑层
/// 负责蛇的移动、碰撞检测、食物/道具生成、计分（含连击）、难度、粒子与游戏循环
final class GameViewModel: ObservableObject {

    // MARK: - 常量

    /// 网格边长（17×17 棋盘）
    static let gridSize = 17

    /// 连击有效窗口（秒）：窗口内连续吃食物累计连击
    private let comboWindow: TimeInterval = 2.5
    /// 道具效果持续时间（秒）
    private let effectDuration: TimeInterval = 4.0

    // MARK: - Published 属性（驱动 UI 更新）

    @Published var snake: [GridPoint] = []
    @Published var food: GridPoint = GridPoint(x: 0, y: 0)
    @Published var direction: Direction = .right
    @Published var score: Int = 0
    @Published var gameState: GameState = .ready

    /// 难度（开始界面可切换）
    @Published var difficulty: Difficulty = .normal
    /// 是否开启道具模式
    @Published var powerUpMode: Bool = true
    /// 当前连击数（>=2 时界面显示「连击 xN」）
    @Published var combo: Int = 0
    /// 棋盘上当前道具（nil 表示没有）
    @Published var powerUp: PowerUp? = nil
    /// 困难模式的障碍格
    @Published var obstacles: [GridPoint] = []
    /// 粒子（吃食物 / 触发道具时的小迸溅）
    @Published var particles: [Particle] = []
    /// 幽灵效果是否生效（可穿身）
    @Published var ghostActive: Bool = false
    /// 当前速度状态（用于界面徽标）
    @Published var speedState: SpeedState = .normal

    /// 最高分（持久化到 UserDefaults）
    @Published var highScore: Int {
        didSet { UserDefaults.standard.set(highScore, forKey: "SnakeHighScore") }
    }

    // MARK: - 私有属性

    /// 下一帧将要应用的方向（防止同一 tick 内连续转向导致掉头）
    private var nextDirection: Direction = .right
    /// 游戏定时器
    private var timer: Timer?
    /// 基础 tick 间隔（吃食物后逐渐加快）
    private var baseInterval: TimeInterval = 0.14
    /// 当前已经应用到 timer 的间隔（用于判断是否需要重启 timer）
    private var appliedInterval: TimeInterval = 0.14

    private var lastEatTime: TimeInterval = 0
    private var speedBoostUntil: TimeInterval = 0
    private var slowUntil: TimeInterval = 0
    private var ghostUntil: TimeInterval = 0

    /// 上一 tick 时蛇的位置（用于平滑插值渲染）
    var prevSnake: [GridPoint] = []
    /// 上一 tick 发生的时间（用于计算插值系数）
    var lastTickDate: Date = Date()

    // MARK: - 初始化

    init() {
        highScore = UserDefaults.standard.integer(forKey: "SnakeHighScore")
        resetGame()
    }

    // MARK: - 游戏控制

    /// 重置游戏到初始状态（依据当前 difficulty / powerUpMode）
    func resetGame() {
        timer?.invalidate()
        timer = nil

        let mid = Self.gridSize / 2
        snake = [
            GridPoint(x: mid - 1, y: mid),
            GridPoint(x: mid - 2, y: mid),
            GridPoint(x: mid - 3, y: mid),
        ]
        prevSnake = snake
        lastTickDate = Date()
        direction = .right
        nextDirection = .right
        score = 0
        combo = 0
        baseInterval = 0.14
        appliedInterval = 0.14
        lastEatTime = 0
        speedBoostUntil = 0
        slowUntil = 0
        ghostUntil = 0
        ghostActive = false
        speedState = .normal
        powerUp = nil
        particles = []
        obstacles = (difficulty == .hard) ? Self.generateObstacles() : []

        gameState = .ready
        placeFood()
    }

    /// 开始游戏
    func startGame() {
        resetGame()
        gameState = .playing
        startTimer()
    }

    /// 暂停 / 继续
    func togglePause() {
        guard gameState == .playing || gameState == .paused else { return }
        if gameState == .playing {
            gameState = .paused
            timer?.invalidate()
        } else {
            gameState = .playing
            startTimer()
        }
    }

    // MARK: - 难度 / 道具模式（开始界面调用）

    func setDifficulty(_ d: Difficulty) {
        difficulty = d
        if gameState == .ready {
            obstacles = (d == .hard) ? Self.generateObstacles() : []
        }
    }

    func setPowerUpMode(_ on: Bool) {
        powerUpMode = on
    }

    // MARK: - 方向控制

    /// 设置下一方向（防止 180° 掉头）
    func changeDirection(_ dir: Direction) {
        // 蛇只有 1 节（刚吃食物的极端情况）时不限制方向
        guard snake.count > 1 else {
            nextDirection = dir
            return
        }
        // 不能直接反方向
        guard dir.opposite != direction else { return }
        nextDirection = dir
    }

    // MARK: - 游戏循环

    private func startTimer() {
        timer?.invalidate()
        appliedInterval = effectiveInterval()
        timer = Timer.scheduledTimer(
            withTimeInterval: appliedInterval,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    /// 依据基础速度与加速/减速效果计算实际间隔
    private func effectiveInterval() -> TimeInterval {
        var i = baseInterval
        let now = Date().timeIntervalSinceReferenceDate
        if now < speedBoostUntil { i *= 0.6 }
        if now < slowUntil { i *= 1.5 }
        return max(0.05, i)
    }

    /// 渲染插值系数（0→1）：在两次 tick 之间平滑滑动，而不是一格一顿
    func interpolationFactor() -> CGFloat {
        guard gameState == .playing else { return 1 }
        let elapsed = Date().timeIntervalSince(lastTickDate)
        let interval = effectiveInterval()
        return CGFloat(min(1, max(0, elapsed / interval)))
    }

    private func restartTimerIfNeeded() {
        let eff = effectiveInterval()
        if abs(eff - appliedInterval) > 0.001 {
            startTimer()
        }
    }

    /// 每个 tick 执行一次：移动蛇、检测碰撞、吃食物 / 道具
    private func tick() {
        let now = Date().timeIntervalSinceReferenceDate

        // 效果到期处理
        if now >= speedBoostUntil && speedState == .fast { speedState = .normal }
        if now >= slowUntil && speedState == .slow { speedState = .normal }
        if now >= ghostUntil { ghostActive = false }

        // 连击窗口过期则清零
        if combo > 0 && now - lastEatTime > comboWindow { combo = 0 }

        direction = nextDirection

        let dirPoint = GridPoint(x: Int(direction.point.x), y: Int(direction.point.y))
        var newHead = snake[0] + dirPoint

        // 墙壁：简单模式穿墙，其余模式撞墙即死
        if difficulty == .easy {
            if newHead.x < 0 { newHead.x = Self.gridSize - 1 }
            else if newHead.x >= Self.gridSize { newHead.x = 0 }
            if newHead.y < 0 { newHead.y = Self.gridSize - 1 }
            else if newHead.y >= Self.gridSize { newHead.y = 0 }
        } else {
            if newHead.x < 0 || newHead.x >= Self.gridSize ||
                newHead.y < 0 || newHead.y >= Self.gridSize {
                endGame()
                return
            }
        }

        // 障碍（困难模式）：撞到即死（幽灵也不能穿越障碍）
        if obstacles.contains(newHead) {
            endGame()
            return
        }

        // 撞自己（幽灵生效时忽略）
        if !ghostActive {
            let bodyToCheck = snake.dropLast()
            if bodyToCheck.contains(newHead) {
                endGame()
                return
            }
        }

        // 记录上一帧位置用于平滑插值渲染
        prevSnake = snake
        lastTickDate = Date()

        snake.insert(newHead, at: 0)

        // 吃到道具
        if let pu = powerUp, pu.position == newHead {
            applyPowerUp(pu.type, at: newHead)
            powerUp = nil
            snake.removeLast()
            updateParticles()
            return
        }

        // 吃食物
        if newHead == food {
            // 连击：窗口内连续吃累计
            if lastEatTime > 0 && now - lastEatTime <= comboWindow {
                combo += 1
            } else {
                combo = 1
            }
            lastEatTime = now

            score += 10 * combo
            if score > highScore { highScore = score }

            spawnParticles(at: newHead, color: 0x64ffda, count: 6)
            baseInterval = max(0.06, baseInterval - 0.003)
            placeFood()

            // 道具模式下，按概率刷新一个道具
            if powerUpMode && powerUp == nil &&
                snake.count < Self.gridSize * Self.gridSize - 6 {
                if Double.random(in: 0..<1) < 0.28 {
                    spawnPowerUp()
                }
            }
            restartTimerIfNeeded()
        } else {
            snake.removeLast()
            updateParticles()
        }
    }

    private func endGame() {
        timer?.invalidate()
        timer = nil
        gameState = .gameOver
    }

    // MARK: - 食物

    /// 在空位随机放置食物
    private func placeFood() {
        var pos: GridPoint
        repeat {
            pos = GridPoint(
                x: Int.random(in: 0..<Self.gridSize),
                y: Int.random(in: 0..<Self.gridSize)
            )
        } while snake.contains(pos) || obstacles.contains(pos) || (powerUp?.position == pos)
        food = pos
    }

    // MARK: - 道具

    private func spawnPowerUp() {
        var pos: GridPoint
        var tries = 0
        repeat {
            pos = GridPoint(
                x: Int.random(in: 0..<Self.gridSize),
                y: Int.random(in: 0..<Self.gridSize)
            )
            tries += 1
        } while (snake.contains(pos) || pos == food || obstacles.contains(pos)) && tries < 100
        let type = PowerUpType.allCases.randomElement() ?? .gold
        powerUp = PowerUp(type: type, position: pos)
    }

    private func applyPowerUp(_ type: PowerUpType, at point: GridPoint) {
        let now = Date().timeIntervalSinceReferenceDate
        switch type {
        case .gold:
            score += 50
            if score > highScore { highScore = score }
            spawnParticles(at: point, color: type.color, count: 12)
        case .fire:
            speedBoostUntil = now + effectDuration
            speedState = .fast
            spawnParticles(at: snake[0], color: type.color, count: 8)
        case .turtle:
            slowUntil = now + effectDuration
            speedState = .slow
            spawnParticles(at: snake[0], color: type.color, count: 8)
        case .ghost:
            ghostUntil = now + effectDuration
            ghostActive = true
            spawnParticles(at: snake[0], color: type.color, count: 8)
        }
        restartTimerIfNeeded()
    }

    // MARK: - 障碍（困难模式）

    /// 在棋盘上生成若干孤立障碍格，避开中心出生安全区
    private static func generateObstacles() -> [GridPoint] {
        let mid = gridSize / 2
        var result: [GridPoint] = []
        var tries = 0
        while result.count < 8 && tries < 300 {
            tries += 1
            let p = GridPoint(
                x: Int.random(in: 1..<(gridSize - 1)),
                y: Int.random(in: 1..<(gridSize - 1))
            )
            // 保留中心 5×5 安全区，避免一出生就被堵
            if abs(p.x - mid) <= 2 && abs(p.y - mid) <= 2 { continue }
            if result.contains(p) { continue }
            result.append(p)
        }
        return result
    }

    // MARK: - 粒子

    private func spawnParticles(at point: GridPoint, color: UInt32, count: Int) {
        let cx = Double(point.x) + 0.5
        let cy = Double(point.y) + 0.5
        for _ in 0..<count {
            let angle = Double.random(in: 0..<(2 * Double.pi))
            let speed = Double.random(in: 0.02...0.08)
            particles.append(Particle(
                x: cx, y: cy,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                life: 1.0,
                decay: Double.random(in: 1.6...2.6),
                color: color,
                size: Double.random(in: 0.08...0.16)
            ))
        }
        if particles.count > 140 {
            particles.removeFirst(particles.count - 140)
        }
    }

    private func updateParticles() {
        let dt = appliedInterval
        for i in particles.indices {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].life -= particles[i].decay * dt
        }
        particles.removeAll { $0.life <= 0 }
    }
}
