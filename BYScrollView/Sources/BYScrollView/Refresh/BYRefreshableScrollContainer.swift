//
//  BYRefreshableScrollContainer.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  刷新 / 加载容器：把下拉刷新、上拉加载能力叠加到 BYScrollView 上。
//

import SwiftUI
import Combine
import UIKit

// MARK: - 滚动内容（刷新悬停 + 页脚注入）

/// 只订阅刷新布局状态。
///
/// Driver 的 headerHeight 会在拖动过程中频繁变化，
/// 这里不直接订阅 Driver，避免每一帧都重建滚动内容。
@MainActor
struct BYRefreshScrollContent<BYContent: View>: View {

    let inner: BYScrollView<BYContent>

    @ObservedObject var layoutState: BYRefreshLayoutState

    let driver: BYRefreshDriver

    let footerBuilder: (BYLoadMoreState) -> AnyView

    let externalGeometry: ((BYScrollGeometry) -> Void)?

    var body: some View {
        inner
            .withTopInset(layoutState.topInset)
            .withBottomContent(
                AnyView(
                    BYRefreshFooterContent(
                        driver: driver,
                        builder: footerBuilder
                    )
                )
            )
            .withScrollViewProbe { [weak driver] scrollView in
                driver?.attachScrollView(scrollView)
            }
            .byGeometryChange { geo in
                driver.handleGeometry(geo)
                externalGeometry?(geo)
            }
    }
}

// MARK: - 刷新容器

/// 为 `BYScrollView` 叠加下拉刷新与上拉加载能力的容器。
///
/// 容器只持有 `BYRefreshDriver`，**不订阅**其高频 @Published 更新；
/// 高频几何由 Driver 直接消费，Header / Footer 分别由独立叶子视图订阅，
/// 保证滚动过程中滚动内容不会被逐帧重建。
@MainActor
public struct BYRefreshableScrollContainer<BYContent: View>: View {
    private let inner: BYScrollView<BYContent>
    private let config: BYRefreshConfiguration
    private let headerBuilder: (BYRefreshState, CGFloat) -> AnyView
    private let footerBuilder: (BYLoadMoreState) -> AnyView
    private let externalGeometry: ((BYScrollGeometry) -> Void)?

    // 容器只持有 driver，不订阅其逐帧 @Published 更新；由叶子视图分别订阅。
    @State private var driver = BYRefreshDriver()

    init(inner: BYScrollView<BYContent>,
         config: BYRefreshConfiguration,
         headerBuilder: @escaping (BYRefreshState, CGFloat) -> AnyView,
         footerBuilder: @escaping (BYLoadMoreState) -> AnyView,
         externalGeometry: ((BYScrollGeometry) -> Void)?) {
        self.inner = inner
        self.config = config
        self.headerBuilder = headerBuilder
        self.footerBuilder = footerBuilder
        self.externalGeometry = externalGeometry
    }

    public var body: some View {
        driver.onRefresh = config.onRefresh
        driver.onLoadMore = config.onLoadMore
        driver.refreshThreshold = config.refreshThreshold
        driver.loadMoreThreshold = config.loadMoreThreshold
        driver.showsFooterWhenContentFits = config.showsFooterWhenContentFits
        return BYRefreshScrollContent(
            inner: inner,
            layoutState: driver.layoutState,
            driver: driver,
            footerBuilder: footerBuilder,
            externalGeometry: externalGeometry
        )
        .overlay(alignment: .top) {
            BYRefreshHeaderOverlay(
                driver: driver,
                builder: headerBuilder
            )
        }
        .onAppear {
            driver.handleHasMoreChange(config.hasMore)

            // 配置开启时进入页面即自动刷新，无需手动下拉。
            if config.autoRefreshOnAppear {
                driver.triggerRefresh()
            }
        }
        .onChange(of: config.hasMore) { newValue in
            driver.handleHasMoreChange(newValue)
        }
    }

    // MARK: - 默认 UI

    static func defaultHeader(
        state: BYRefreshState,
        progress: CGFloat
    ) -> AnyView {
        AnyView(BYRefreshDefaultHeader(state: state, progress: progress))
    }

    static func defaultFooter(
        state: BYLoadMoreState
    ) -> AnyView {
        AnyView(BYRefreshDefaultFooter(state: state))
    }
}

// MARK: - 容器链式自定义

extension BYRefreshableScrollContainer {
    public func byRefreshHeader<H: View>(
        @ViewBuilder _ builder: @escaping (BYRefreshState, CGFloat) -> H
    ) -> Self {
        let copy = self
        return copy.rebuild(
            header: { state, progress in AnyView(builder(state, progress)) },
            footer: nil,
            external: nil
        )
    }

    public func byLoadMoreFooter<F: View>(
        @ViewBuilder _ builder: @escaping (BYLoadMoreState) -> F
    ) -> Self {
        rebuild(header: nil, footer: { state in AnyView(builder(state)) }, external: nil)
    }

    /// 追加几何监听。`.byRefresh(...)` 已接管 inner 的 `byGeometryChange`，
    /// 需要同时感知几何时用本方法追加，避免二次覆盖。
    public func onScrollGeometry(_ handler: @escaping (BYScrollGeometry) -> Void) -> Self {
        rebuild(header: nil, footer: nil, external: handler)
    }

    private func rebuild(
        header: ((BYRefreshState, CGFloat) -> AnyView)?,
        footer: ((BYLoadMoreState) -> AnyView)?,
        external: ((BYScrollGeometry) -> Void)?
    ) -> Self {
        .init(inner: inner,
              config: config,
              headerBuilder: header ?? headerBuilder,
              footerBuilder: footer ?? footerBuilder,
              externalGeometry: external ?? externalGeometry)
    }
}

// MARK: - 链式接入

extension BYScrollView {
    /// 为当前 BYScrollView 叠加下拉刷新与上拉加载能力。
    ///
    /// - 会**接管**当前实例的 `byGeometryChange`。若调用方之前已配置，
    ///   原 handler 被覆盖；需要同时监听时使用返回容器的 `.onScrollGeometry { }` 追加。
    /// - 刷头以 `overlay` 固定在视口顶部；`.refreshing` 时内容整体下推
    ///   `refreshThreshold` 高度，刷头"挂住"，呈现 MJRefresh 式悬停。
    /// - 加载更多页脚挂在滚动内容**尾部**（在流内），滚动到底即自然露出；
    ///   高度由加载状态驱动（idle=0 / loading=50 / noMore=24）。
    /// - `hasMore` 变化会自动同步到 driver：`false` 时页脚展示"没有更多"，
    ///   重新置 `true` 即恢复加载能力（对应 MJRefresh 的 `resetNoMoreData()`）。
    /// - `autoRefreshOnAppear` 置 `true` 时，进入页面即自动进入 `.refreshing`
    ///   并执行 `onRefresh`（对应 MJRefresh 的 `beginRefreshing()`）；
    ///   默认 `false`，由用户手动下拉触发。
    public func byRefresh(
        refreshThreshold: CGFloat = 80,
        loadMoreThreshold: CGFloat = 24,
        showsFooterWhenContentFits: Bool = false,
        autoRefreshOnAppear: Bool = false,
        hasMore: Bool = true,
        onRefresh: (() async -> Void)? = nil,
        onLoadMore: (() async -> Void)? = nil
    ) -> BYRefreshableScrollContainer<BYContent> {
        BYRefreshableScrollContainer(
            inner: self,
            config: BYRefreshConfiguration(
                refreshThreshold: refreshThreshold,
                loadMoreThreshold: loadMoreThreshold,
                showsFooterWhenContentFits: showsFooterWhenContentFits,
                autoRefreshOnAppear: autoRefreshOnAppear,
                hasMore: hasMore,
                onRefresh: onRefresh,
                onLoadMore: onLoadMore
            ),
            headerBuilder: Self.defaultHeaderBuilder,
            footerBuilder: Self.defaultFooterBuilder,
            externalGeometry: nil
        )
    }

    // 静态转发，避免在泛型上下文里写 `BYRefreshableScrollContainer<BYContent>.defaultXxx`
    private static var defaultHeaderBuilder: (BYRefreshState, CGFloat) -> AnyView {
        BYRefreshableScrollContainer<BYContent>.defaultHeader
    }
    private static var defaultFooterBuilder: (BYLoadMoreState) -> AnyView {
        BYRefreshableScrollContainer<BYContent>.defaultFooter
    }
}
