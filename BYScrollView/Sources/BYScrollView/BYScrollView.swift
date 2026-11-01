//
//  BYScrollView.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  通用滚动组件：基础 ScrollView 封装 + 跨版本几何监听。
//  下拉刷新 / 上拉加载见 Refresh/ 目录，通过 `.byRefresh(...)` 链式接入。
//

import SwiftUI
import Combine

/// 一个可感知内容尺寸与滚动偏移的 ScrollView 封装。
///
/// 设计目标：
/// 1. **跨版本语义统一**：iOS 15–17 用 `GeometryReader + PreferenceKey` 测量，
///    iOS 18+ 用原生 `onScrollGeometryChange`，对外暴露的 `BYScrollGeometry`
///    中 `contentOffset` / `contentSize` / `containerSize` 在两端精度一致。
/// 2. **单实例 / 多实例双维度 API**：单点回调 + 字典回调 + 父视图平级聚合。
/// 3. **嵌套隔离可控**：默认每层只回调本层数据（`isolatesNestedChanges = true`），
///    需要嵌套聚合时显式传 `false`。
/// 4. **去重不触发重建**：高频写入的"上次上报值"用引用类型 + `@State` 持有，
///    写入内部字段不会让 body 失效。
///
/// UI 组件，标注 `@MainActor` 以保证在主线程使用。
@MainActor
public struct BYScrollView<BYContent>: View where BYContent: View {
    // MARK: - 公开配置

    public var axes: Axis.Set = .vertical
    public var showsIndicators: Bool = false

    // MARK: - 内容与回调存储

    private var contentView: BYContent

    /// 刷新悬停：`.refreshing` 时把内容整体下推的距离（= refreshThreshold），
    /// 让刷头在释放后"挂住"，呈现 MJRefresh 式悬停。其余状态为 0，不影响布局。
    private var topInset: CGFloat = 0
    /// 挂在滚动内容**尾部**的附加内容（如加载更多页脚），跟随内容流滚动。
    /// 为 nil 时对布局零影响。
    private var bottomContentView: AnyView? = nil

    /// 刷新悬停的宿主 `UIScrollView` 回调（内部使用）。
    ///
    /// `byRefresh` 容器注入探针：找到 SwiftUI ScrollView 底层的 UIScrollView，
    /// 供刷新悬停用 `contentInset.top` 精确顶起（MJRefresh 同款机制）。
    /// 普通使用（未接 `byRefresh`）时为 nil，探针不挂载、零开销。
    private var scrollViewProbe: ((UIScrollView) -> Void)? = nil

    /// 单实例：内容尺寸变化
    private var contentSizeChange: ((CGSize) -> Void)? = nil
    /// 单实例：滚动偏移变化
    private var contentOffsetChange: ((CGPoint) -> Void)? = nil
    /// 多实例：内容尺寸字典变化（key 为各实例的 resolvedID）
    private var contentSizePreferenceChange: (([UUID: CGSize]) -> Void)? = nil
    /// 多实例：滚动偏移字典变化
    private var contentOffsetPreferenceChange: (([UUID: CGPoint]) -> Void)? = nil
    /// 跨版本统一几何快照回调
    private var geometryChange: ((BYScrollGeometry) -> Void)? = nil

    /// iOS 18+ 独占的完整 `ScrollGeometry` 回调。
    ///
    /// 用 `Any?` 擦除类型：`ScrollGeometry` 是 iOS 18 才有的类型，不能作为
    /// 存储属性出现在支持 iOS 15 的 struct 里。通过 `fullGeometryChange`
    /// 计算属性在 iOS 18+ 上下文中做类型转换。
    private var fullGeometryChangeRaw: Any? = nil

    /// 嵌套时是否只回调本层数据。true 时用 `transformPreference` 过滤掉子层 ID。
    private var isolatesNestedChanges: Bool = true

    // MARK: - 实例标识与坐标空间

    private let providedID: UUID?
    private var resolvedID: UUID { providedID ?? generatedID }
    /// 每个实例独立的命名坐标空间，供 iOS 15–17 分支的 GeometryReader 使用。
    /// iOS 18 分支的偏移直接来自 `ScrollGeometry.contentOffset`，不使用该坐标空间。
    private var coordinateSpaceName: String { "BYScrollView_\(resolvedID)" }

    // MARK: - 内部状态

    @State private var generatedID = UUID()

    /// 上次已上报的 size / offset / geometry，用于去重。
    /// 引用类型：写入内部字段不触发 body 重建（详见类注释）。
    @State private var lastReportedStore = BYScrollViewLastReportedStore()

    /// 容器尺寸缓存。两分支都写入它：
    /// - iOS 15–17：来自 ScrollView 外层的 GeometryReader
    /// - iOS 18+：来自 `ios18Geometry.containerSize` 经 ContainerSizeKey preference 中转
    @State private var fallbackState = BYScrollViewFallbackState()

    /// iOS 18 几何快照由引用类型持有；逐帧变化只刷新轻量 emitter，
    /// 不让 BYScrollView 主体及用户内容随每一帧重新计算。
    @State private var ios18GeometryStore = BYScrollViewGeometryStore()

    @available(iOS 18.0, *)
    fileprivate var fullGeometryChange: ((ScrollGeometry) -> Void)? {
        get { fullGeometryChangeRaw as? (ScrollGeometry) -> Void }
        set { fullGeometryChangeRaw = newValue }
    }

    public init(byID: UUID? = nil,
                axes: Axis.Set = .vertical,
                showsIndicators: Bool = false,
                isolatesNestedChanges: Bool = true,
                @ViewBuilder contentView: () -> BYContent) {
        self.providedID = byID
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.isolatesNestedChanges = isolatesNestedChanges
        self.contentView = contentView()
    }

    // MARK: - 内容装饰（刷新悬停 + 尾部页脚）

    /// 内容装饰：把 `contentView` 包一层 `VStack`——
    /// - 顶部加 `topInset` 让内容在刷新悬停时整体下推；
    /// - 尾部可挂加载更多页脚（`bottomContentView`），随内容流滚动到底。
    ///
    /// 两分支（iOS 18+ / iOS 15–17）共用，保证几何测量与布局语义一致：
    /// 页脚进入 `contentSize`，由真实的滚动位置驱动加载更多。
    @ViewBuilder
    private var decoratedContent: some View {
        VStack(spacing: 0) {
            contentView
                .padding(.top, topInset)
            if let bottom = bottomContentView {
                bottom
            }
        }
    }

    /// 内部：设置刷新悬停顶插距。
    func withTopInset(_ inset: CGFloat) -> Self {
        var copy = self
        copy.topInset = inset
        return copy
    }

    /// 内部：设置滚动内容尾部的附加内容（加载更多页脚）。
    func withBottomContent(_ content: AnyView?) -> Self {
        var copy = self
        copy.bottomContentView = content
        return copy
    }

    /// 内部：挂载宿主 `UIScrollView` 探针（刷新容器注入）。
    func withScrollViewProbe(_ probe: ((UIScrollView) -> Void)?) -> Self {
        var copy = self
        copy.scrollViewProbe = probe
        return copy
    }

    // MARK: - Body

    @ViewBuilder
    public var body: some View {
        if #available(iOS 18.0, *) {
            bodyModern
        } else {
            bodyLegacy
        }
    }

    // MARK: - iOS 18+ 分支

    @available(iOS 18.0, *)
    private var bodyModern: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            decoratedContent
                .background(scrollViewProbe.map { BYScrollViewHostFinder(onFound: $0) })
                .background(
                    BYScrollViewGeometryPreferenceEmitter(
                        id: resolvedID,
                        store: ios18GeometryStore
                    )
                )
            // 嵌套隔离：只保留本实例 ID，丢弃子树内其它 BYScrollView 贡献的数据。
            // 传 false 时不做过滤，外层字典回调即可收到内层数据（嵌套聚合）。
                .transformPreference(BYScrollViewContentSizePreferenceKey.self) { value in
                    if isolatesNestedChanges {
                        value = value.filter { $0.key == resolvedID }
                    }
                }
                .transformPreference(BYScrollViewContentOffsetPreferenceKey.self) { value in
                    if isolatesNestedChanges {
                        value = value.filter { $0.key == resolvedID }
                    }
                }
        }
        // 统一几何：只取跨版本精度一致的三个字段，写入 @State 驱动上面的 Preference。
        .onScrollGeometryChange(
            for: BYScrollGeometry.self,
            of: { geo in
                BYScrollGeometry(
                    contentOffset: geo.contentOffset,
                    contentSize: geo.contentSize,
                    containerSize: geo.containerSize
                )
            },
            action: { _, newValue in
                ios18GeometryStore.geometry = newValue
            }
        )
        // 完整几何：iOS 18 独有能力，直接透传给 `byFullGeometryChange`。
        // 不走 Preference，因为它包含 iOS 15 无法提供的字段，不进入统一接口。
        // `onScrollGeometryChange` 内部按 `ScrollGeometry: Equatable` 比较，
        // 几何不变时 action 不触发。
        .onScrollGeometryChange(
            for: ScrollGeometry.self,
            of: { $0 },
            action: { _, newValue in
                (fullGeometryChangeRaw as? (ScrollGeometry) -> Void)?(newValue)
            }
        )
        .onPreferenceChange(BYScrollViewContentSizePreferenceKey.self) { dic in
            handleSizePreferenceChange(dic)
        }
        .onPreferenceChange(BYScrollViewContentOffsetPreferenceKey.self) { dic in
            handleOffsetPreferenceChange(dic)
        }
        .onPreferenceChange(BYScrollViewContainerSizePreferenceKey.self) { size in
            fallbackState.containerSize = size
            publishGeometryIfReady()
        }
    }

    // MARK: - iOS 15–17 分支

    /// 用 `GeometryReader + PreferenceKey` 测量。
    ///
    /// 探针位置：
    /// - 偏移探针放在 **ScrollView 内容内部**（`contentView.background`），
    ///   只有内容坐标才会随滚动变化；放在 ScrollView 外层测不到偏移。
    /// - 容器尺寸：iOS 15–17 上 `.background(GeometryReader)` 挂到
    ///   ScrollView 外层会测量失败（实测恒为 0），因此改用**外层 GeometryReader
    ///   包裹 ScrollView**，从包裹层的尺寸取容器大小，与 iOS 18 的
    ///   `ScrollGeometry.containerSize` 语义对齐。
    private var bodyLegacy: some View {
        GeometryReader { container in
            ScrollView(axes, showsIndicators: showsIndicators) {
                decoratedContent
                    .background(scrollViewProbe.map { BYScrollViewHostFinder(onFound: $0) })
                    .background(
                        GeometryReader { proxy in
                            let frame = proxy.frame(in: .named(coordinateSpaceName))
                            Color.clear
                                .preference(
                                    key: BYScrollViewContentSizePreferenceKey.self,
                                    value: [resolvedID: proxy.size]
                                )
                                .preference(
                                    key: BYScrollViewContentOffsetPreferenceKey.self,
                                    // 取反：内容向上移动时 minY 变负，取反后与 UIKit contentOffset 语义一致。
                                    value: [resolvedID: CGPoint(x: -frame.minX, y: -frame.minY)]
                                )
                        }
                    )
                // 与 iOS 18 分支相同的嵌套隔离逻辑。
                    .transformPreference(BYScrollViewContentSizePreferenceKey.self) { value in
                        if isolatesNestedChanges {
                            value = value.filter { $0.key == resolvedID }
                        }
                    }
                    .transformPreference(BYScrollViewContentOffsetPreferenceKey.self) { value in
                        if isolatesNestedChanges {
                            value = value.filter { $0.key == resolvedID }
                        }
                    }
            }
            .coordinateSpace(name: coordinateSpaceName)
            // 容器尺寸：外层 GeometryReader 的实测尺寸，直接以 preference 上报。
            .preference(
                key: BYScrollViewContainerSizePreferenceKey.self,
                value: container.size
            )
        }
        .onPreferenceChange(BYScrollViewContainerSizePreferenceKey.self) { size in
            fallbackState.containerSize = size
            publishGeometryIfReady()
        }
        .onPreferenceChange(BYScrollViewContentSizePreferenceKey.self) { dic in
            handleSizePreferenceChange(dic)
        }
        .onPreferenceChange(BYScrollViewContentOffsetPreferenceKey.self) { dic in
            handleOffsetPreferenceChange(dic)
        }
    }

    // MARK: - 统一回调分发（两分支共用）

    /// 处理尺寸变化：去重 → 单实例回调 → 字典回调 → 尝试合成统一几何。
    ///
    /// `guard` 双重作用：
    /// 1. 过滤 `dic` 中没有本实例的情况；
    /// 2. 过滤与上次相同的值，避免重复回调。
    private func handleSizePreferenceChange(_ dic: [UUID: CGSize]) {
        guard let size = dic[resolvedID], size != lastReportedStore.size else { return }
        lastReportedStore.size = size
        contentSizePreferenceChange?(dic)
        contentSizeChange?(size)
        publishGeometryIfReady()
    }

    /// 处理偏移变化：与尺寸同理。
    private func handleOffsetPreferenceChange(_ dic: [UUID: CGPoint]) {
        guard let offset = dic[resolvedID], offset != lastReportedStore.offset else { return }
        lastReportedStore.offset = offset
        contentOffsetPreferenceChange?(dic)
        contentOffsetChange?(offset)
        publishGeometryIfReady()
    }

    /// size / offset / containerSize 任一更新时尝试合成 `BYScrollGeometry`。
    ///
    /// 数据源：
    /// - iOS 18+：直接用 `ios18Geometry`（已含完整三个字段）。
    /// - iOS 15–17：用 `lastReportedStore` + `fallbackState` 组合。
    ///
    /// 用 `lastReportedStore.geometry` 去重，同一快照只回调一次。
    private func publishGeometryIfReady() {
        let geo: BYScrollGeometry
        if #available(iOS 18.0, *), let g = ios18GeometryStore.geometry {
            geo = g
        } else {
            guard let size = lastReportedStore.size,
                  let offset = lastReportedStore.offset,
                  let containerSize = fallbackState.containerSize else { return }
            geo = BYScrollGeometry(contentOffset: offset, contentSize: size, containerSize: containerSize)
        }
        guard geo != lastReportedStore.geometry else { return }
        lastReportedStore.geometry = geo
        geometryChange?(geo)
    }
}

// MARK: - 链式配置 API

extension BYScrollView where BYContent: View {
    /// 单实例：监听内容尺寸变化。
    public func byContentSizeChange(_ param: @escaping (CGSize) -> Void) -> BYScrollView<BYContent> {
        var copy = self
        copy.contentSizeChange = param
        return copy
    }

    /// 单实例：监听滚动偏移变化。
    public func byContentOffsetChange(_ param: @escaping (CGPoint) -> Void) -> BYScrollView<BYContent> {
        var copy = self
        copy.contentOffsetChange = param
        return copy
    }

    /// 多实例：监听内容尺寸字典变化。
    /// 嵌套场景下 `dic` 的内容取决于 `isolatesNestedChanges`：
    /// - true（默认）：只含本层 `[resolvedID: size]`
    /// - false：含本层及所有未隔离的子层数据（嵌套聚合）
    public func byContentSizePreferenceChange(_ param: @escaping ([UUID: CGSize]) -> Void) -> BYScrollView<BYContent> {
        var copy = self
        copy.contentSizePreferenceChange = param
        return copy
    }

    /// 多实例：监听滚动偏移字典变化，语义同上。
    public func byContentOffsetPreferenceChange(_ param: @escaping ([UUID: CGPoint]) -> Void) -> BYScrollView<BYContent> {
        var copy = self
        copy.contentOffsetPreferenceChange = param
        return copy
    }

    /// 跨版本统一几何回调，`contentOffset` / `contentSize` / `containerSize` 精度一致。
    /// 调用者无需 `#available` 判断即可安全使用。
    public func byGeometryChange(_ param: @escaping (BYScrollGeometry) -> Void) -> BYScrollView<BYContent> {
        var copy = self
        copy.geometryChange = param
        return copy
    }

    /// 设置嵌套隔离策略。默认 true（每层只看自己）。
    ///
    /// 嵌套聚合需要**内外层都传 false**。内层若保持 true，
    /// 它会在自己的 `transformPreference` 处把数据截断，外层收不到。
    public func byNestedIsolation(_ value: Bool) -> BYScrollView<BYContent> {
        var copy = self
        copy.isolatesNestedChanges = value
        return copy
    }

    /// iOS 18+ 独有：完整原生 `ScrollGeometry`（含 `contentInsets` / `visibleRect` / `bounds`）。
    ///
    /// 这些字段在 iOS 15–17 上无法精确获取，不进入统一接口 `BYScrollGeometry`，
    /// 通过这个带 `@available` 的方法单独暴露，版本差异由调用者显式承担。
    ///
    /// `onScrollGeometryChange` 内部基于 `ScrollGeometry: Equatable` 比较，
    /// 几何不变时 action 不触发。
    @available(iOS 18.0, *)
    public func byFullGeometryChange(_ param: @escaping (ScrollGeometry) -> Void) -> BYScrollView<BYContent> {
        var copy = self
        copy.fullGeometryChange = param
        return copy
    }
}
