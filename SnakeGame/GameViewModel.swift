import Foundation
import SwiftUI
import Combine

// MARK: - GameViewModel

/// 贪食蛇游戏逻辑层
/// 负责蛇的移动、碰撞检测、食物生成、计分和游戏循环
final class GameViewModel: ObservableObject {

    // MARK: - 常量

    /// 网格边长（17×17 棋盘）
    static let gridSize = 17

    // MARK: - Published 属性（驱动 UI 更新）

    @Published var snake: [GridPoint] = []
    @Published var food: GridPoint = GridPoint(x: 0, y: 0)
    @Published var direction: Direction = .right
    @Published var score: Int = 0
    @Published var gameState: GameState = .ready

    // MARK: - 私有属性

    /// 下一帧将要应用的方向（防止同一 tick 内连续转向导致掉头）
    private var nextDirection: Direction = .right

    /// 游戏定时器
    private var timer: Timer?

    /// 当前 tick 间隔（毫秒），吃食物后逐渐加快
    private var tickInterval: TimeInterval = 0.14

    /// 最高分（持久化到 UserDefaults）
    @Published var highScore: Int {
        didSet { UserDefaults.standard.set(highScore, forKey: "SnakeHighScore") }
    }

    // MARK: - 初始化

    init() {
        highScore = UserDefaults.standard.integer(forKey: "SnakeHighScore")
        resetGame()
    }

    // MARK: - 游戏控制

    /// 重置游戏到初始状态
    func resetGame() {
        timer?.invalidate()
        timer = nil

        let mid = Self.gridSize / 2
        snake = [
            GridPoint(x: mid - 1, y: mid),
            GridPoint(x: mid - 2, y: mid),
            GridPoint(x: mid - 3, y: mid),
        ]
        direction = .right
        nextDirection = .right
        score = 0
        tickInterval = 0.14
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

    // MARK: - 方向控制

    /// 设置下一方向（防止 180° 掉头）
    /// - Parameter dir: 玩家输入的方向
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
        timer = Timer.scheduledTimer(
            withTimeInterval: tickInterval,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    /// 每个 tick 执行一次：移动蛇、检测碰撞、吃食物
    private func tick() {
        direction = nextDirection

        let dirPoint = GridPoint(x: Int(direction.point.x), y: Int(direction.point.y))
        let newHead = snake[0] + dirPoint

        // 撞墙
        if newHead.x < 0 || newHead.x >= Self.gridSize ||
            newHead.y < 0 || newHead.y >= Self.gridSize {
            endGame()
            return
        }

        // 撞自己（尾巴会在移动后移走，所以最后一节除外）
        let bodyToCheck = snake.dropLast()
        if bodyToCheck.contains(newHead) {
            endGame()
            return
        }

        snake.insert(newHead, at: 0)

        // 吃食物
        if newHead == food {
            score += 10
            if score > highScore { highScore = score }
            // 加速：最低 0.06s
            tickInterval = max(0.06, tickInterval - 0.003)
            placeFood()
            // 重新启动 timer 以应用新速度
            if gameState == .playing {
                startTimer()
            }
        } else {
            snake.removeLast()
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
        } while snake.contains(pos)
        food = pos
    }
}
