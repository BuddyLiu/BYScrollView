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

    public var hasMore: Bool

    public var onRefresh: (() async -> Void)?

    public var onLoadMore: (() async -> Void)?

    public init(
        refreshThreshold: CGFloat = 80,
        loadMoreThreshold: CGFloat = 24,
        showsFooterWhenContentFits: Bool = false,
        hasMore: Bool = true,
        onRefresh: (() async -> Void)? = nil,
        onLoadMore: (() async -> Void)? = nil
    ) {
        self.refreshThreshold = refreshThreshold
        self.loadMoreThreshold = loadMoreThreshold
        self.showsFooterWhenContentFits = showsFooterWhenContentFits
        self.hasMore = hasMore
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
    }
}
