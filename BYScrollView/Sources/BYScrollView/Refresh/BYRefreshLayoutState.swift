//
//  BYRefreshLayoutState.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  只负责刷新时内容顶部的占位高度，与 Driver 分离。
//

import SwiftUI
import Combine

/// 只负责刷新时内容顶部的占位高度。
/// 与 BYRefreshDriver 分离，避免下拉过程中的 headerHeight 高频变化
/// 导致整个 BYScrollView 频繁重建。
@MainActor
final class BYRefreshLayoutState: ObservableObject {
    @Published var topInset: CGFloat = 0
}
