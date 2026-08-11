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

// MARK: - Grid Point

/// 网格坐标（整数坐标）
struct GridPoint: Equatable, Hashable {
    var x: Int
    var y: Int

    static func + (lhs: GridPoint, rhs: GridPoint) -> GridPoint {
        GridPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
