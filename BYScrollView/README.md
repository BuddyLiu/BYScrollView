# BYScrollView

一个可直接拷贝进任意 SwiftUI 工程的滚动组件：基础 ScrollView 封装 + 跨 iOS 版本统一的几何监听 + 下拉刷新 / 上拉加载更多（MJRefresh 交互时序）。

**不依赖 Package 管理**：整个 `BYScrollView/` 文件夹拷走即用。

## 目录结构

```
BYScrollView/
├── BYScrollView.swift                # 主体：ScrollView 封装 + 几何监听链式 API
├── BYScrollGeometry.swift            # 跨版本统一几何快照（contentOffset/contentSize/containerSize）
├── BYScrollViewPreferenceKey.swift   # PreferenceKey + 平级实例聚合
├── BYScrollViewGeometryStore.swift   # 高频写入 Store + UIScrollView 探针
├── BYDebug.swift                     # DEBUG 沙盒日志（可选，仅 DEBUG 生效）
├── Preview/
│   └── BYScrollViewPreview.swift     # 9 个 #Preview 示例
└── Refresh/
    ├── BYRefreshState.swift                # 状态枚举
    ├── BYRefreshConfiguration.swift        # 刷新配置
    ├── BYRefreshLayoutState.swift          # 刷新悬停顶部占位
    ├── BYRefreshPanObserver.swift          # 手势监听（松手/取消）
    ├── BYRefreshDriver.swift               # 状态机 Driver
    ├── BYRefreshHeader.swift               # 默认刷头 + 悬停 overlay
    ├── BYRefreshFooter.swift               # 默认页脚 + 流内 Footer
    └── BYRefreshableScrollContainer.swift  # 刷新容器 + byRefresh 入口
```

## 集成

1. 将 `BYScrollView/` 整个文件夹拷贝到工程源码目录。
2. 工程若使用 Xcode 16 的 **PBXFileSystemSynchronizedRootGroup**（文件系统同步组），新文件自动加入编译，无需改 pbxproj；否则在 Xcode 中 `Add Files...` 加入。
3. 最低部署目标 **iOS 15.0**，无需额外 framework。

## 快速开始

### 基础滚动

```swift
BYScrollView(axes: .vertical) {
    VStack(spacing: 12) {
        ForEach(0..<30, id: \.self) { i in
            Text("第 \(i) 行").frame(maxWidth: .infinity, alignment: .leading).padding()
        }
    }
    .padding()
}
```

- `axes`：`.vertical` / `.horizontal`
- `showsIndicators`：是否显示滚动指示条，默认 `false`
- `byID`：给实例一个稳定 ID，多实例场景区分数据用（不传自动生成）

### 下拉刷新 + 上拉加载

```swift
BYScrollView(axes: .vertical) {
    LazyVStack(spacing: 12) {
        ForEach(vm.items) { item in /* 列表项 */ }
    }
    .padding()
}
.byRefresh(
    refreshThreshold: 80,       // 下拉触发刷新的距离
    loadMoreThreshold: 24,      // 到底后继续上拉的触发距离
    hasMore: vm.hasMore,
    onRefresh: { await vm.reload() },
    onLoadMore: { await vm.loadMore() }
)
```

**注意**：`.byRefresh` 会接管当前实例的 `byGeometryChange`。需要同时监听几何时，用返回容器的 `.onScrollGeometry { }` 追加。

### 自定义刷头 / 页脚

```swift
.byRefresh(refreshThreshold: 80, loadMoreThreshold: 24, hasMore: vm.hasMore,
           onRefresh: { await vm.reload() }, onLoadMore: { await vm.loadMore() })
.byRefreshHeader { state, progress in
    HStack(spacing: 10) {
        if state == .refreshing {
            ProgressView().tint(.blue)
        } else {
            Image(systemName: "arrow.down").rotationEffect(.degrees(progress * 180))
        }
        Text(state == .armed ? "释放立即刷新" : "下拉刷新")
    }
}
.byLoadMoreFooter { state in
    switch state {
    case .loading:    ProgressView().tint(.green); Text("加载中...")
    case .noMore:     Text("没有更多了")
    default:          Text("上拉加载")
    }
}
```

刷头回调参数 `(state: BYRefreshState, progress: CGFloat)`：
`state` 驱动文案，`progress`（0~1）驱动箭头/动画。页脚回调 `state: BYLoadMoreState`。

### 几何监听

```swift
BYScrollView { /* 内容 */ }
    .byContentSizeChange  { size = $0 }     // CGSize
    .byContentOffsetChange { offset = $0 }   // CGPoint
    .byGeometryChange { geo in }            // 统一快照 BYScrollGeometry
    .byFullGeometryChange { g in }          // 仅 iOS 18+，原生 ScrollGeometry
```

**iOS 15–17** 走 `GeometryReader + PreferenceKey`，**iOS 18+** 走原生 `onScrollGeometryChange`，对外暴露的 `BYScrollGeometry` 三字段在两端精度一致。

### 多实例（平级聚合）

多个子实例各自带 `byID`，父视图一次拿到全部：

```swift
HStack {
    BYScrollView(byID: firstID)  { /* 左列表 */ }
    BYScrollView(byID: secondID) { /* 右列表 */ }
}
.byScrollViewGeometryAggregate(
    onSizeChange: { sizes = $0 },     // [UUID: CGSize]
    onOffsetChange: { offsets = $0 }  // [UUID: CGPoint]
)
```

### 嵌套滚动隔离

默认 `isolatesNestedChanges = true`：外层只收到自己的数据，内层滚动不污染外层回调。

```swift
BYScrollView(axes: .vertical, isolatesNestedChanges: true) {
    BYScrollView(byID: innerID) { /* 内层列表 */ }.frame(height: 160)
}
.byContentSizePreferenceChange { sizes in }  // 只含外层自己的 ID
```

### 短列表 Footer 控制

```swift
.byRefresh(..., showsFooterWhenContentFits: true, hasMore: true, onLoadMore: ...)
```

内容不足一屏时默认不显示 Footer；需要时传 `showsFooterWhenContentFits: true`。

## 公开 API

| API | 说明 |
|---|---|
| `BYScrollView(byID:axes:showsIndicators:isolatesNestedChanges:contentView:)` | 主体 |
| `byContentSizeChange(_:)` / `byContentOffsetChange(_:)` | 单实例几何回调 |
| `byContentSizePreferenceChange(_:)` / `byContentOffsetPreferenceChange(_:)` | 多实例字典回调 |
| `byGeometryChange(_:)` | 跨版本统一几何快照 |
| `byFullGeometryChange(_:)` | iOS 18+ 完整 ScrollGeometry |
| `byNestedIsolation(_:)` | 开关嵌套隔离 |
| `byScrollViewGeometryAggregate(onSizeChange:onOffsetChange:)` | 父视图平级聚合 |
| `byRefresh(refreshThreshold:loadMoreThreshold:showsFooterWhenContentFits:hasMore:onRefresh:onLoadMore:)` | 叠加刷新/加载 |
| `byRefreshHeader(_:)` / `byLoadMoreFooter(_:)` | 自定义刷头 / 页脚 |
| `onScrollGeometry(_:)` | 容器上追加几何监听 |

## 状态机（交互时序，禁止随意改动）

下拉刷新与上拉加载的统一 Driver（`BYRefreshDriver`），交互时序经过多轮真机调试确定：

1. **Header 达阈值只进 `.armed`，必须松手才刷新**。松手判断用 `lastOverscroll`，不重读未经校准的 UIKit offset。
2. **达阈值后反向拖回阈值以内，立即恢复 `.pulling`**。
3. 刷新悬停：`updatePinnedInset` 每帧动态补偿，恒满足 `topInset + overscroll = refreshThreshold`，列表"挂住"呈现 MJRefresh 式悬停。
4. 刷新结束两阶段：先 `0.28s` 让 Header 跟随 ScrollView 移出屏幕，再复位 `idle`；保留负偏移，下一次下拉时无动画复位。
5. **Footer 同样松手触发**：仅 `scrollView.isDragging` 时进入 `.armed`，底部 Bounce overscroll 超过 `loadMoreThreshold` 后在松手时加载；`wasAtBottom` 标记防止停在底部重复触发。
6. Footer 高度固定 44pt，**严禁用 `Color.clear` / `Spacer` 额外撑高 contentSize**；显示与否由 `shouldShowFooter` 决定是否参与布局。**不传 `onLoadMore`（`nil`）时整块不渲染**，只做下拉刷新也不会出现"上拉加载更多"页脚。
7. `hasMore = false` 显示"没有更多"，重新置 `true` 自动恢复加载能力（对应 MJRefresh `resetNoMoreData()`）。

## 性能设计

- 容器只持有 Driver，**不订阅**其逐帧 `@Published`；Header / Footer 为独立**叶子视图**各自订阅，滚动中业务列表不会被逐帧重建。
- 高频几何写入引用类型 `@State` Store，去重不触发 body 重建。
- 首帧采样 `baseOffset`，之后不重置；手势判断一律用校准后的 `lastOverscroll`。
- 未接 `.byRefresh` 时探针不挂载，零开销。

## 测试

`BYRefreshScrollViewTests` 内含 17 个状态机单元测试（`@MainActor`），覆盖：阈值判定、松手触发、反向取消、手势取消、悬停补偿、刷新复位、Footer 短列表 / 高度 / 未拖动不 armed / noMore 切换。当前工程 17/17 通过。
