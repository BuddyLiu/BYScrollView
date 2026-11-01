//
//  BYRefreshHeader.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  刷新 Header 的叶子视图：默认样式 + 悬停 overlay。
//

import SwiftUI

// MARK: - 默认 Header 样式

/// 默认刷头 UI，参照 MJRefresh 的 `MJRefreshNormalHeader`。
///
/// | 状态 | 默认 UI |
/// |---|---|
/// | idle | 隐藏 |
/// | pulling | 向下箭头 + 下拉可以刷新 |
/// | armed | 向上翻转箭头 + 松开立即刷新 |
/// | refreshing | Loading + 正在刷新数据中... |
struct BYRefreshDefaultHeader: View {
    let state: BYRefreshState
    let progress: CGFloat

    var body: some View {
        Group {
            switch state {
                case .idle:
                    Color.clear

                case .pulling:
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down")
                            .rotationEffect(
                                .degrees(min(max(progress, 0), 1) * 180.0)
                            )

                        Text("下拉可以刷新")
                    }

                case .armed:
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down")
                            .rotationEffect(.degrees(180))

                        Text("松开立即刷新")
                    }

                case .refreshing:
                    HStack(spacing: 12) {
                        ProgressView()
                            .frame(width: 18, height: 18)

                        Text("正在刷新数据中...")
                    }
            }
        }
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("by-refresh-header")
    }
}

// MARK: - Header 悬停 overlay

/// Header overlay：以 `.overlay(alignment: .top)` 固定在视口顶部。
///
/// 只订阅 Driver 的刷头相关 @Published（state / height / exitOffset / opacity），
/// 是独立叶子视图；Driver 其它高频字段变化不会重建它，更不会重建滚动内容。
@MainActor
struct BYRefreshHeaderOverlay: View {
    @ObservedObject var driver: BYRefreshDriver
    let builder: (BYRefreshState, CGFloat) -> AnyView

    var body: some View {
        builder(driver.refreshState, driver.refreshProgress)
            .frame(maxWidth: .infinity)
            .frame(height: driver.headerHeight)
//            .clipped()
            .background(Color.clear)

        // 跟随 ScrollView 的复位动画向上移出。
            .offset(y: driver.headerExitOffset)

        // 拖动时渐显，退出动画完成后隐藏。
            .opacity(driver.headerOpacity)

            .allowsHitTesting(false)
    }
}
