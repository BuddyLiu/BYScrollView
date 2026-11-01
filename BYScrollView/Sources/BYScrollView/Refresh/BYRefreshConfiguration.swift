//
//  BYRefreshConfiguration.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  下拉刷新 / 上拉加载的统一配置模型。
//

import Foundation

/// 刷新与加载的统一配置。`byRefresh(...)` 的参数集中在这里，
/// 避免公共 API 出现过多零散参数。
public struct BYRefreshConfiguration {

    /// 下拉刷新阈值：下拉距离达到该值进入 armed，松手触发刷新。
    public var refreshThreshold: CGFloat

    /// 底部 Bounce 触发加载距离：内容滚到底后继续上拉该距离进入 armed。
    public var loadMoreThreshold: CGFloat

    /// 内容不足一屏时，是否仍然显示 Footer。
    public var showsFooterWhenContentFits: Bool

    /// 进入页面后是否自动触发一次刷新。
    ///
    /// 默认为 `false`，刷新只能由用户手动下拉触发。
    /// 置 `true` 时，视图每次 `onAppear` 自动进入 `.refreshing`：
    /// 刷头直接以悬停样式显示并执行 `onRefresh`，无需手动下滑，
    /// 对应 MJRefresh 的 `beginRefreshing()` 自动刷新场景。
    public var autoRefreshOnAppear: Bool

    public var hasMore: Bool

    public var onRefresh: (() async -> Void)?

    public var onLoadMore: (() async -> Void)?

    public init(
        refreshThreshold: CGFloat = 80,
        loadMoreThreshold: CGFloat = 24,
        showsFooterWhenContentFits: Bool = false,
        autoRefreshOnAppear: Bool = false,
        hasMore: Bool = true,
        onRefresh: (() async -> Void)? = nil,
        onLoadMore: (() async -> Void)? = nil
    ) {
        self.refreshThreshold = refreshThreshold
        self.loadMoreThreshold = loadMoreThreshold
        self.showsFooterWhenContentFits = showsFooterWhenContentFits
        self.autoRefreshOnAppear = autoRefreshOnAppear
        self.hasMore = hasMore
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
    }
}
