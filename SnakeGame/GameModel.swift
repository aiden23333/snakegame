import Foundation
import SwiftUI

// MARK: - Direction

/// 蛇的移动方向，用 x/y 偏移量表示
enum Direction: Int, CaseIterable {
    case up, down, left, right

    var point: CGPoint {
        switch self {
        case .up:    return CGPoint(x: 0, y: -1)
        case .down:  return CGPoint(x: 0, y: 1)
        case .left:  return CGPoint(x: -1, y: 0)
        case .right: return CGPoint(x: 1, y: 0)
        }
    }

    /// 返回相反方向（用于防止蛇掉头）
    var opposite: Direction {
        switch self {
        case .up:    return .down
        case .down:  return .up
        case .left:  return .right
        case .right: return .left
        }
    }

    /// 角色头部图标朝向角度（弧度），用于旋转蛇头
    var headRotation: Angle {
        switch self {
        case .right: return .degrees(0)
        case .down:  return .degrees(90)
        case .left:  return .degrees(180)
        case .up:    return .degrees(270)
        }
    }
}

// MARK: - Game State

/// 游戏状态机
enum GameState {
    case ready      // 初始界面
    case playing    // 游戏中
    case paused     // 暂停
    case gameOver   // 结束
}

// MARK: - Difficulty

/// 难度：简单（穿墙）/ 普通（撞墙即死）/ 困难（撞墙 + 内部障碍）
enum Difficulty: Int, CaseIterable {
    case easy, normal, hard

    var title: String {
        switch self {
        case .easy:   return "简单"
        case .normal: return "普通"
        case .hard:   return "困难"
        }
    }

    var subtitle: String {
        switch self {
        case .easy:   return "穿墙模式"
        case .normal: return "撞墙即死"
        case .hard:   return "墙 + 障碍"
        }
    }
}

// MARK: - Speed State（用于 UI 状态徽标）

enum SpeedState {
    case normal, fast, slow
}

// MARK: - PowerUp Type

/// 道具类型
enum PowerUpType: CaseIterable {
    case gold    // 金苹果：大量加分
    case fire    // 加速
    case turtle  // 减速
    case ghost   // 幽灵：短暂可穿身

    var emoji: String {
        switch self {
        case .gold:   return "🍎"
        case .fire:   return "🔥"
        case .turtle: return "🐢"
        case .ghost:  return "👻"
        }
    }

    /// 用于发光与粒子着色的颜色
    var color: UInt32 {
        switch self {
        case .gold:   return 0xffd700
        case .fire:   return 0xff6b35
        case .turtle: return 0x4ade80
        case .ghost:  return 0xa78bfa
        }
    }

    var label: String {
        switch self {
        case .gold:   return "金苹果 +50"
        case .fire:   return "加速"
        case .turtle: return "减速"
        case .ghost:  return "幽灵穿身"
        }
    }
}

/// 棋盘上当前存在的道具（同一时刻最多一个）
struct PowerUp {
    var type: PowerUpType
    var position: GridPoint
}

// MARK: - Particle

/// 吃食物 / 触发道具时的小粒子（坐标为「格」单位，绘制时乘以 cell）
struct Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Double      // 1.0 -> 0.0
    var decay: Double     // 每个 tick 衰减量
    var color: UInt32
    var size: Double      // 格单位
}

// MARK: - Grid Point

/// 网格坐标（整数坐标）
struct GridPoint: Equatable, Hashable {
    var x: Int
    var y: Int

    static func + (lhs: GridPoint, rhs: GridPoint) -> GridPoint {
        GridPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
