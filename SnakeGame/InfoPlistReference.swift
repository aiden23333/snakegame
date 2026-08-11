import SwiftUI
import UniformTypeIdentifiers

/// 用 SwiftUI App 方式创建的 iOS 项目，Info.plist 中大部分 key 由 Xcode 的
/// General -> Signing & Capabilities 和 Info 面板管理。以下为参考配置。
///
/// ExampleInfo.plist 仅作参考。实际 Info.plist 可在 Xcode 中通过
/// target -> Info 面板编辑，或选择 General 面板设置。

enum InfoPlistReference {
    /// CFBundleDisplayName
    static let displayName = "贪食蛇"
    /// CFBundleShortVersionString
    static let version = "1.0"
    /// CFBundleVersion
    static let build = "1"
    /// UILaunchScreen（空字典 = 使用 SwiftUI 默认启动屏）
    static let launchScreen: [String: Any] = [:]
    /// 支持竖屏
    static let orientations: [String] = ["UIInterfaceOrientationPortrait"]
    /// 最低 iOS 版本
    static let minVersion = "16.0"
}
