//
//  BYRefreshFooter.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  加载更多 Footer 的叶子视图：默认样式 + 挂在滚动内容尾部的页脚。
//

import SwiftUI

// MARK: - 默认 Footer 样式

/// 默认页脚 UI，参照 MJRefresh 的 `MJRefreshAutoNormalFooter`。
///
/// | 状态 | 默认 UI |
/// |---|---|
/// | idle | 向上箭头 + 上拉加载更多 |
/// | armed | 松开立即加载 |
/// | loading | Loading + 正在加载更多的数据... |
/// | noMore | 已经全部加载完毕 |
struct BYRefreshDefaultFooter: View {
    let state: BYLoadMoreState

    var body: some View {
        Group {
            switch state {
                case .idle:
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up")
                        Text("上拉加载更多")
                    }

                case .armed:
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down")
                        Text("松开立即加载")
                    }

                case .loading:
                    HStack(spacing: 8) {
                        ProgressView()
                            .frame(width: 16, height: 16)
                        Text("正在加载更多的数据...")
                    }

                case .noMore:
                    Text("已经全部加载完毕")
            }
        }
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("by-load-more-footer")
    }
}

// MARK: - Footer 叶子视图

/// 挂在滚动内容**尾部**的 Footer 叶子视图。
///
/// 只订阅 Driver 的 `loadMoreState` / `footerHeight` / `shouldShowFooter`，
/// 状态变化不会引起业务列表整体布局重建。
///
/// **不额外占位**：是否渲染完全由 `shouldShowFooter` 决定——`false` 时（包括
/// `onLoadMore` 未传、内容不足一屏且未开 `showsFooterWhenContentFits`）整块为空，
/// 零布局影响，严禁用 `Color.clear` / `Spacer` 等占位撑高 contentSize。
@MainActor
struct BYRefreshFooterContent: View {
    @ObservedObject var driver: BYRefreshDriver
    let builder: (BYLoadMoreState) -> AnyView

    var body: some View {
        if driver.shouldShowFooter {
            builder(driver.loadMoreState)
                .frame(maxWidth: .infinity)
                .frame(height: driver.footerHeight)
                .background(Color(.systemBackground))
                .accessibilityIdentifier("by-load-more-footer")
                .animation(.easeInOut(duration: 0.2), value: driver.loadMoreState)
        }
    }
}
