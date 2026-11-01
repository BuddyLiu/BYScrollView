//
//  BYRefreshDriver.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  刷新 / 加载状态机 Driver：统一管理下拉刷新与上拉加载的状态流转。
//

import SwiftUI
import Combine
import UIKit

/// 刷新与加载的统一 Driver。
///
/// 状态机约束（经过多轮真机调试确定，禁止随意改动交互时序）：
/// 1. Header 达到阈值只是进入 `.armed`，**必须松手**（`handlePanEnded`）才刷新。
/// 2. Header 达到阈值后反向拖回阈值以内，立即恢复 `.pulling`。
/// 3. 刷新过程中动态补偿顶部占位（`updatePinnedInset`），保持列表悬停。
/// 4. 刷新结束先让 Header 跟随 ScrollView 移出屏幕，再复位状态。
/// 5. Footer 同样**松手触发**；停留在底部 Bounce 区域不重复触发。
///
/// 松手判断与几何判断共用 `lastOverscroll` / `lastLoadMoreOverscroll`，
/// 不重新读取未经校准的 UIKit contentOffset。
@MainActor
final class BYRefreshDriver: ObservableObject {
    @Published private(set) var refreshState: BYRefreshState = .idle
    @Published private(set) var headerHeight: CGFloat = 0
    @Published private(set) var loadMoreState: BYLoadMoreState = .idle

    var refreshThreshold: CGFloat = 80
    /// ScrollView 到达内容底部后，继续上拉的触发距离。
    /// 通过 Bounce 产生的 overscroll 判断，不增加实际滚动内容高度。
    public var loadMoreThreshold: CGFloat = 24
    var hasMore: Bool = true
    var onRefresh: (() async -> Void)?
    var onLoadMore: (() async -> Void)?

    /// Header 退出屏幕的偏移量。
    /// 刷新结束时从 0 动画到 -refreshThreshold。
    @Published private(set) var headerExitOffset: CGFloat = 0
    /// Header 当前透明度。
    /// 下拉过程中随距离变化，刷新结束时渐隐。
    @Published private(set) var headerOpacity: CGFloat = 0
    /// 当前是否显示 Footer。
    @Published private(set) var shouldShowFooter = false

    /// 内容不足一屏时是否仍然显示 Footer。
    var showsFooterWhenContentFits = false
    /// 刷新结束动画任务。
    private var finishTask: Task<Void, Never>?
    /// 顶部无 overscroll 时的 offset 基准。首帧采样，之后不重置。
    private var baseOffset: CGFloat?
    /// 最近一次几何事件的 overscroll，供 `startRefresh` 起步时的顶插取连续值。
    private var lastOverscroll: CGFloat = 0
    /// 最近一次底部超出 contentSize 的距离。
    private var lastLoadMoreOverscroll: CGFloat = 0
    /// 宿主 UIScrollView（`BYScrollViewHostFinder` 探针找到，经容器注入）。
    /// 悬停改 `contentInset.top` 用；找不到时为 nil，退回 padding 方案。
    /// 底层 UIScrollView。
    weak var scrollView: UIScrollView?

    /// 手势监听器，必须强引用，避免监听器提前释放。
    private var panObserver: BYRefreshPanObserver?

    /// 是否正在执行刷新结束动画。
    /// 结束动画期间禁止动态调整 topInset，避免与退出动画冲突。
    private var isFinishingRefresh = false
    /// 刷新前的原始 inset；结束刷新时恢复，避免覆盖安全区/调用方配置。
    private var originalContentInsetTop: CGFloat?
    /// 上拉到达触发区后的"是否仍停在触发区"标记，防止 LazyVStack 惰性
    /// 展开导致 contentSize 边滚边涨时反复触发 loadMore。
    /// 离开触发区或刷新时会重置，允许再次到达时补触发。
    private var wasAtBottom = false
    private var refreshTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?

    var refreshProgress: CGFloat {
        guard refreshThreshold > 0 else { return 0 }
        return min(headerHeight / refreshThreshold, 1)
    }

    var footerHeight: CGFloat {
        guard onLoadMore != nil,
              shouldShowFooter else {
            return 0
        }

        return 44
    }

    let layoutState = BYRefreshLayoutState()

    // MARK: - 入口

    func attachScrollView(_ scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else { return }

        if let oldScrollView = self.scrollView,
           let observer = panObserver {
            oldScrollView.panGestureRecognizer.removeTarget(
                observer,
                action: #selector(BYRefreshPanObserver.handle(_:))
            )
        }

        self.scrollView = scrollView

        // baseOffset 只允许由 handleGeometry 的 BYScrollGeometry 初始化。

        let observer = BYRefreshPanObserver(driver: self)
        panObserver = observer

        scrollView.panGestureRecognizer.addTarget(
            observer,
            action: #selector(BYRefreshPanObserver.handle(_:))
        )

#if DEBUG
        BYDebug.shared.log("driver: pan observer attached")
#endif
    }

    /// 获取手势结束瞬间的真实下拉距离。
//    private func currentOverscroll() -> CGFloat {
//        guard let scrollView,
//              let baseOffset else {
//            return lastOverscroll
//        }
//
//        return max(0, baseOffset - scrollView.contentOffset.y)
//    }

    func handleGeometry(_ geo: BYScrollGeometry) {
        let offsetY = geo.contentOffset.y

        if baseOffset == nil {
            baseOffset = offsetY
        }

        let base = baseOffset ?? offsetY
        let overscroll = max(0, base - offsetY)

        lastOverscroll = overscroll

        if refreshState == .refreshing {

            // 刷新期间动态补偿，保持列表悬停。
            // 刷新结束动画期间禁止修改，避免与退出动画打架。
            if !isFinishingRefresh {
                updatePinnedInset(for: overscroll)
            }

        } else {

            updatePull(overscroll: overscroll)
        }

        updateLoadMore(geo)
    }

    /// 手指松开：
    /// - Header：达到下拉阈值才触发刷新。
    /// - Footer：达到底部超出阈值才触发加载更多。
    func handlePanEnded() {
        guard refreshState != .refreshing else { return }

        // MARK: Header

        if refreshState == .armed,
           lastOverscroll >= refreshThreshold {
            startRefresh(overscroll: lastOverscroll)
            return
        }

        // MARK: Footer

        guard loadMoreState == .armed,
              lastLoadMoreOverscroll > loadMoreThreshold else {
            return
        }

        // 锁定本次触发，防止加载完成但仍停留在底部时重复触发。
        wasAtBottom = true
        startLoadMore()
    }

    /// 手势被系统取消时，不触发刷新。
    func handlePanCancelled() {
        guard refreshState != .refreshing else { return }

        // 使用最后一次几何数据，不重新读取 UIKit offset。
        updatePull(overscroll: lastOverscroll)
    }

    private func startRefresh(overscroll: CGFloat = 0) {
        guard refreshState != .refreshing else { return }

        finishTask?.cancel()
        finishTask = nil

        isFinishingRefresh = false

        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            headerExitOffset = 0
            headerOpacity = 1
            refreshState = .refreshing
            headerHeight = refreshThreshold
        }

        updatePinnedInset(for: overscroll)

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }

            await self.onRefresh?()

            guard !Task.isCancelled else { return }
            self.finishRefresh()
        }
    }

    // MARK: - 下拉

    /// 仅根据当前拖动距离更新状态。
    /// 注意：此方法绝不触发刷新，刷新只能由 handlePanEnded 触发。
    private func updatePull(overscroll: CGFloat) {
        // 上一次刷新结束后，Header 保留着负偏移。
        // 下一次真正开始下拉时，无动画恢复 Header 的初始位置。
        // 此时 Header 透明度仍由下拉距离控制，因此不会突然显示出来。
        if overscroll > 0.5, headerExitOffset != 0 {
            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                headerExitOffset = 0
            }
        }
        // 下拉达到阈值一半时，Header 完全显示。
        let fadeDistance = max(refreshThreshold * 0.5, 1)
        let opacity = min(max(overscroll / fadeDistance, 0), 1)

        if abs(headerOpacity - opacity) > 0.01 {
            headerOpacity = opacity
        }

        if overscroll <= 0.5 {
            if refreshState != .idle {
                refreshState = .idle
            }

            if headerHeight != 0 {
                headerHeight = 0
            }

            return
        }

        if overscroll >= refreshThreshold {
            if refreshState != .armed {
                refreshState = .armed
            }
        } else {
            if refreshState != .pulling {
                refreshState = .pulling
            }
        }

        if abs(headerHeight - overscroll) > 0.5 {
            headerHeight = overscroll
        }
    }

    /// 根据当前 overscroll 动态补偿顶部占位。
    ///
    /// 目标：
    /// overscroll + topInset = refreshThreshold
    ///
    /// ScrollView 回弹时，overscroll 减少，topInset 同步增加，
    /// 从视觉上让列表始终停留在刷新悬停位置。
    private func updatePinnedInset(for overscroll: CGFloat) {

        let targetInset = max(
            0,
            refreshThreshold - overscroll
        )

        guard abs(layoutState.topInset - targetInset) > 0.5 else {
            return
        }

        // 滚动回弹期间禁止隐式动画。
        // 否则 topInset 自身也会滞后，反而造成抖动。
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            layoutState.topInset = targetInset
        }
    }

    /// 幂等重设宿主 `contentInset.top`：刷新中 = 补偿式 `max(0, threshold + offsetY)`，
    /// 其余 = 0。由 `handleGeometry` 每帧调用，防 SwiftUI 布局阶段重置 inset。
    ///
    /// 补偿式理由见 `startRefresh`：本宿主 P = -offset + adjustedContentInset.top，
    /// 回弹期间 offset 连续变化，用 `threshold + offset` 抵消才能恒钉在 threshold。
    private func applyPin(on scrollView: UIScrollView) {
        let baseInset = originalContentInsetTop ?? scrollView.contentInset.top
        let compensation = refreshState == .refreshing
        ? max(0, refreshThreshold + scrollView.contentOffset.y)
        : 0
        let target = baseInset + compensation
        if abs(scrollView.contentInset.top - target) > 0.5 {
            scrollView.contentInset.top = target
        }
    }

    /// 刷新结束：
    /// 1. ScrollView 恢复时，Header 同步向上移出屏幕；
    /// 2. Header 完全移出后，再隐藏并切换 idle；
    /// 3. 保留最终负偏移，等待下一次下拉时复位。
    private func finishRefresh() {
        guard refreshState == .refreshing else { return }

        finishTask?.cancel()
        isFinishingRefresh = true

        let duration: TimeInterval = 0.28
        let exitOffset = -max(headerHeight, refreshThreshold)

        // 第一阶段：
        // ScrollView 内容复位，Header 同步向上移动。
        // 此时 Header 保持完全不透明。
        withAnimation(.easeInOut(duration: duration)) {
            layoutState.topInset = 0
            headerExitOffset = exitOffset
        }

        // 第二阶段：
        // Header 完全移出后，再切换为隐藏状态。
        finishTask = Task { [weak self] in
            let delay = UInt64((duration + 0.04) * 1_000_000_000)

            try? await Task.sleep(nanoseconds: delay)

            guard let self, !Task.isCancelled else { return }

            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                self.refreshState = .idle
                self.headerHeight = 0
                self.headerOpacity = 0

                // 不能在这里把 headerExitOffset 重置为 0。
                // 保留负偏移，防止 Header 再次进入屏幕。
            }

            self.isFinishingRefresh = false
            self.wasAtBottom = false
            self.finishTask = nil
        }
    }

    /// 对外暴露的"代码触发刷新"（空态页按钮等场景）。
    func triggerRefresh() {
        startRefresh(overscroll: 0)
    }

    // MARK: - 上拉

    /// 根据内容高度决定 Footer 是否显示，并判断是否进入加载待触发状态。
    ///
    /// 触发条件：
    /// contentOffset.y + containerSize.height
    ///     > contentSize.height + loadMoreThreshold
    ///
    /// 达到条件只进入 .armed，必须等手势结束才真正加载。
    private func updateLoadMore(_ geo: BYScrollGeometry) {

        // 没有加载更多回调，不显示 Footer。
        guard onLoadMore != nil else {
            if shouldShowFooter {
                shouldShowFooter = false
            }

            if loadMoreState == .armed {
                loadMoreState = .idle
            }

            lastLoadMoreOverscroll = 0
            wasAtBottom = false
            return
        }

        // 排除 Footer 高度，判断真正的业务内容是否超过一屏。
        let actualContentHeight = max(
            0,
            geo.contentSize.height - footerHeight
        )

        let contentCanScroll =
        actualContentHeight > geo.containerSize.height + 0.5

        // 短列表是否显示 Footer。
        let targetShowFooter =
        contentCanScroll || showsFooterWhenContentFits

        if shouldShowFooter != targetShowFooter {
            shouldShowFooter = targetShowFooter
            wasAtBottom = false

            if loadMoreState == .armed {
                loadMoreState = .idle
            }

            return
        }

        // 内容不足一屏，不触发加载。
        guard contentCanScroll else {
            if loadMoreState == .armed {
                loadMoreState = .idle
            }

            lastLoadMoreOverscroll = 0
            wasAtBottom = false
            return
        }

        // 刷新期间不触发加载。
        guard refreshState != .refreshing else {
            if loadMoreState == .armed {
                loadMoreState = .idle
            }
            return
        }

        // 已经没有更多数据。
        guard hasMore else {
            if loadMoreState != .noMore {
                loadMoreState = .noMore
            }

            wasAtBottom = false
            return
        }

        guard loadMoreState != .loading,
              loadMoreState != .noMore else {
            return
        }

        // 计算底部 overscroll。
        let visibleBottom =
        geo.contentOffset.y + geo.containerSize.height

        let bottomOverscroll = max(
            0,
            visibleBottom - geo.contentSize.height
        )

        lastLoadMoreOverscroll = bottomOverscroll

        // 上一次已经触发加载：
        // 等待 ScrollView 回到正常范围后，才允许下一次加载。
        if wasAtBottom {
            if bottomOverscroll <= 0.5 {
                wasAtBottom = false
            }
            return
        }

        // 必须是用户当前正在拖动，不能因为系统回弹或减速动画进入 armed。
        let isDragging = scrollView?.isDragging == true

        if bottomOverscroll > loadMoreThreshold && isDragging {

            // 达到阈值，只进入待释放状态。
            if loadMoreState != .armed {
                loadMoreState = .armed
            }

        } else if bottomOverscroll <= loadMoreThreshold {

            // 用户尚未松手就反向拖回阈值范围，取消加载。
            if loadMoreState == .armed {
                loadMoreState = .idle
            }
        }
    }

    private func startLoadMore() {
        guard loadMoreState != .loading else { return }
        loadMoreState = .loading
#if DEBUG
        BYDebug.shared.log("driver: loadMore start")
#endif
        loadMoreTask?.cancel()
        loadMoreTask = Task { [weak self] in
            guard let self else { return }
            await self.onLoadMore?()
            guard !Task.isCancelled else { return }
            self.loadMoreState = self.hasMore ? .idle : .noMore
        }
    }

    func handleHasMoreChange(_ value: Bool) {
        hasMore = value
        if !value {
            if loadMoreState == .idle { loadMoreState = .noMore }
        } else {
            if loadMoreState == .noMore { loadMoreState = .idle }
            // 重新有更多：清除"停在底部"标记，允许下一次到达触发区时重新触发。
            wasAtBottom = false
        }
    }
}
