# BYScrollView

> 一个可感知内容尺寸与滚动偏移的 SwiftUI `ScrollView` 封装，跨 iOS 15+ 提供语义一致的滚动几何观测，并内置下拉刷新 / 上拉加载更多（MJRefresh 交互时序）。

## 目录

- [特性](#特性)
- [安装](#安装)
- [目录结构](#目录结构)
- [快速开始](#快速开始)
- [数据模型](#数据模型)
- [API 参考](#api-参考)
  - [初始化](#初始化)
  - [单实例回调](#单实例回调)
  - [多实例字典回调](#多实例字典回调)
  - [跨版本统一几何](#跨版本统一几何)
  - [iOS 18+ 完整几何](#ios-18-完整几何)
  - [嵌套隔离](#嵌套隔离)
  - [父视图平级聚合](#父视图平级聚合)
  - [刷新 / 加载（byRefresh）](#刷新--加载byrefresh)
  - [自定义刷头 / 页脚](#自定义刷头--页脚)
- [状态机（交互时序）](#状态机交互时序)
- [使用示例](#使用示例)
- [版本兼容](#版本兼容)
- [性能设计](#性能设计)
- [注意事项](#注意事项)
- [相关类型](#相关类型)
- [测试](#测试)

---

## 特性

| 特性 | 说明 |
|---|---|
| **跨版本语义统一** | iOS 15–17 用 `GeometryReader + PreferenceKey` 测量；iOS 18+ 用原生 `onScrollGeometryChange`。对外暴露的 `contentOffset` / `contentSize` / `containerSize` 两端精度一致 |
| **三层观测 API** | 单实例回调、多实例字典回调、父视图平级聚合，覆盖单点与多实例场景 |
| **嵌套隔离可控** | 默认每层只回调本层数据；需要嵌套聚合时内外层显式传 `false` |
| **去重不触发重建** | 高频写入的"上次上报值"用引用类型 + `@State` 持有，写入内部字段不驱动 body 重建 |
| **完整几何（iOS 18+）** | 额外暴露原生 `ScrollGeometry`，含 `contentInsets` / `visibleRect` / `bounds` 等 iOS 15–17 无法精确获取的字段 |
| **下拉刷新 / 上拉加载** | 统一状态机 Driver，MJRefresh 式交互时序（阈值悬停、松手触发、noMore 恢复） |
| **刷头 / 页脚可定制** | `byRefreshHeader` / `byLoadMoreFooter` 替换默认 UI，不依赖自定义 UIKit 视图 |

---

## 安装

### Swift Package Manager

**远端仓库**：在 Xcode 中 `File → Add Packages...` → 输入地址 `https://github.com/BuddyLiu/BYScrollView.git` → 版本规则选择 `Up to Next Major 1.0.0` → 添加 `BYScrollView` 到 target。

或直接在 `Package.swift` 中声明依赖：

```swift
dependencies: [
    .package(url: "https://github.com/BuddyLiu/BYScrollView.git", from: "1.0.0")
]
```

**本地 Package**（Demo 工程即采用此方式）：将本仓库的 `BYScrollView/` 文件夹加入工程，Xcode 会自动识别其中的 `Package.swift`，随后在 target 的 Frameworks 中添加 `BYScrollView` product。引用方代码 `import BYScrollView` 即可。

> 使用 Package 导入时，**必须**在每个用到库类型（`BYScrollView` / `BYScrollGeometry` / `BYRefreshState` 等）的文件顶部 `import BYScrollView`。相比旧版"拷贝源码进 target"的方式，这是唯一需要额外注意的点。

### CocoaPods

在 `Podfile` 中：

```ruby
pod 'BYScrollView', :git => 'https://github.com/BuddyLiu/BYScrollView.git', :tag => '1.0.0'
```

> 也可以直接引用指定 tag 或 commit：`:tag => '1.0.0'` / `:commit => 'xxxxxxx'`。
> 提交到 [CocoaPods 公共 spec 仓库](https://trunk.cocoapods.org) 后，即可直接 `pod 'BYScrollView'`。

### 手动拷贝

将 `BYScrollView/Sources/BYScrollView/` 下的源码文件拷贝进工程源码目录。工程若使用 Xcode 16 的 **PBXFileSystemSynchronizedRootGroup**（文件系统同步组），新文件自动加入编译，无需改 pbxproj；否则在 Xcode 中 `Add Files...` 加入。此种方式下无需 `import`（文件直接编译进 target）。

两种包管理器（SPM / CocoaPods）与拷贝方式共用同一份源码，API 完全一致。最低部署目标 **iOS 15.0**，无需额外 framework。

---

## 目录结构

```
BYScrollView/                          # 本仓库 = 一个 Swift Package
├── Package.swift                      # SPM 清单（product: BYScrollView）
├── BYScrollView.podspec               # CocoaPods spec
├── Sources/
│   └── BYScrollView/
│       ├── BYScrollView.swift                # 主体：ScrollView 封装 + 几何监听链式 API
│       ├── BYScrollGeometry.swift            # 跨版本统一几何快照（contentOffset/contentSize/containerSize）
│       ├── BYScrollViewPreferenceKey.swift   # PreferenceKey + 平级实例聚合
│       ├── BYScrollViewGeometryStore.swift   # 高频写入 Store + UIScrollView 探针
│       ├── BYDebug.swift                     # DEBUG 沙盒日志（可选，仅 DEBUG 生效）
│       ├── Preview/
│       │   └── BYScrollViewPreview.swift     # #Preview 示例
│       └── Refresh/
│           ├── BYRefreshState.swift                # 状态枚举
│           ├── BYRefreshConfiguration.swift        # 刷新配置
│           ├── BYRefreshLayoutState.swift          # 刷新悬停顶部占位
│           ├── BYRefreshPanObserver.swift          # 手势监听（松手/取消）
│           ├── BYRefreshDriver.swift               # 状态机 Driver
│           ├── BYRefreshHeader.swift               # 默认刷头 + 悬停 overlay
│           ├── BYRefreshFooter.swift               # 默认页脚 + 流内 Footer
│           └── BYRefreshableScrollContainer.swift  # 刷新容器 + byRefresh 入口
```

---

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

### 几何监听

```swift
BYScrollView { /* 内容 */ }
    .byContentSizeChange  { size = $0 }     // CGSize
    .byContentOffsetChange { offset = $0 }   // CGPoint
    .byGeometryChange { geo in }            // 统一快照 BYScrollGeometry
    .byFullGeometryChange { g in }          // 仅 iOS 18+，原生 ScrollGeometry
```

**iOS 15–17** 走 `GeometryReader + PreferenceKey`，**iOS 18+** 走原生 `onScrollGeometryChange`，对外暴露的 `BYScrollGeometry` 三字段在两端精度一致。

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

### 进入即刷新

开启 `autoRefreshOnAppear` 后，进入页面无需手动下拉，自动进入 `.refreshing` 并执行 `onRefresh`（对应 MJRefresh 的 `beginRefreshing()`）：

```swift
.byRefresh(
    autoRefreshOnAppear: true,   // 默认 false：手动下拉触发
    hasMore: vm.hasMore,
    onRefresh: { await vm.reload() }
)
```

视图每次 `onAppear` 都会触发；刷新进行中再次出现不会重复触发。

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

---

## 数据模型

### `BYScrollGeometry`

跨 iOS 15+ 语义一致的滚动几何快照。三个字段在所有支持版本上精度一致。

```swift
struct BYScrollGeometry: Equatable {
    var contentOffset: CGPoint   // 滚动偏移，与 UIKit contentOffset 语义一致
    var contentSize: CGSize      // 内容尺寸
    var containerSize: CGSize    // 滚动容器尺寸
}
```

> **不包含** `contentInsets` / `visibleRect` / `bounds`：这些字段在 iOS 15–17 无法精确获取，放进统一接口会让调用者误以为跨版本可信。需要时请用 [`byFullGeometryChange`](#ios-18-完整几何)（仅 iOS 18+）。

---

## API 参考

| API | 说明 |
|---|---|
| `BYScrollView(byID:axes:showsIndicators:isolatesNestedChanges:contentView:)` | 主体 |
| `byContentSizeChange(_:)` / `byContentOffsetChange(_:)` | 单实例几何回调 |
| `byContentSizePreferenceChange(_:)` / `byContentOffsetPreferenceChange(_:)` | 多实例字典回调 |
| `byGeometryChange(_:)` | 跨版本统一几何快照 |
| `byFullGeometryChange(_:)` | iOS 18+ 完整 ScrollGeometry |
| `byNestedIsolation(_:)` | 开关嵌套隔离 |
| `byScrollViewGeometryAggregate(onSizeChange:onOffsetChange:)` | 父视图平级聚合 |
| `byRefresh(refreshThreshold:loadMoreThreshold:showsFooterWhenContentFits:autoRefreshOnAppear:hasMore:onRefresh:onLoadMore:)` | 叠加刷新/加载 |
| `byRefreshHeader(_:)` / `byLoadMoreFooter(_:)` | 自定义刷头 / 页脚 |
| `onScrollGeometry(_:)` | 容器上追加几何监听 |

### 初始化

```swift
BYScrollView(
    byID: UUID? = nil,                    // 显式实例 ID（多实例场景）；不传则内部自动生成
    axes: Axis.Set = .vertical,           // 滚动方向
    showsIndicators: Bool = false,        // 是否显示指示器
    isolatesNestedChanges: Bool = true,   // 嵌套时是否只回调本层数据
    @ViewBuilder contentView: () -> BYContent
)
```

| 参数 | 默认值 | 说明 |
|---|---|---|
| `byID` | `nil` | 外部显式传入的实例 ID。不传时内部自动生成稳定 UUID（视图生命周期内不变）。多实例字典回调时用作字典 key |
| `axes` | `.vertical` | 滚动轴 |
| `showsIndicators` | `false` | 滚动指示器 |
| `isolatesNestedChanges` | `true` | `true` 时每层只回调本层数据；`false` 时外层可见内层数据（嵌套聚合） |

### 单实例回调

监听**本层**的内容尺寸与滚动偏移。

```swift
func byContentSizeChange(_ param: @escaping (CGSize) -> Void) -> BYScrollView<BYContent>
func byContentOffsetChange(_ param: @escaping (CGPoint) -> Void) -> BYScrollView<BYContent>
```

```swift
BYScrollView { content }
    .byContentSizeChange { size in
        print("contentSize: \(size)")
    }
    .byContentOffsetChange { offset in
        print("offset: \(offset)")
    }
```

内部按值去重，相同值不会重复回调。

### 多实例字典回调

监听**字典**形式的变化，key 为各实例的 `resolvedID`。

```swift
func byContentSizePreferenceChange(_ param: @escaping ([UUID: CGSize]) -> Void) -> BYScrollView<BYContent>
func byContentOffsetPreferenceChange(_ param: @escaping ([UUID: CGPoint]) -> Void) -> BYScrollView<BYContent>
```

字典内容取决于 `isolatesNestedChanges`：

- `true`（默认）：只含本层 `[resolvedID: 值]`
- `false`：含本层及所有未隔离的子层数据（嵌套聚合）

```swift
BYScrollView(byID: myID) { content }
    .byContentOffsetPreferenceChange { dic in
        if let myOffset = dic[myID] {
            // ...
        }
    }
```

### 跨版本统一几何

一次性拿到 `contentOffset` / `contentSize` / `containerSize` 三个字段，调用者无需 `#available` 判断。

```swift
func byGeometryChange(_ param: @escaping (BYScrollGeometry) -> Void) -> BYScrollView<BYContent>
```

触发时机：`size` / `offset` / `containerSize` 任一更新且合成结果与上次不同。用 `lastReportedStore.geometry` 去重，同一快照只回调一次。

数据源：

- iOS 18+：直接用 `ios18Geometry`（已含完整三个字段）
- iOS 15–17：用 `lastReportedStore` + `fallbackState` 组合

### iOS 18+ 完整几何

暴露原生 `ScrollGeometry`，含 `contentInsets` / `visibleRect` / `bounds` 等字段。

```swift
@available(iOS 18.0, *)
func byFullGeometryChange(_ param: @escaping (ScrollGeometry) -> Void) -> BYScrollView<BYContent>
```

```swift
if #available(iOS 18.0, *) {
    BYScrollView { content }
        .byFullGeometryChange { geometry in
            print("visibleRect: \(geometry.visibleRect)")
            print("contentInsets: \(geometry.contentInsets)")
        }
}
```

> 这些字段在 iOS 15–17 无法精确获取，不进入统一接口，版本差异由调用者显式承担。
> `onScrollGeometryChange` 内部基于 `ScrollGeometry: Equatable` 比较，几何不变时 action 不触发。

### 嵌套隔离

```swift
func byNestedIsolation(_ value: Bool) -> BYScrollView<BYContent>
```

默认 `true`（每层只看自己）。

**嵌套聚合需要内外层都传 `false`**。内层若保持 `true`，它会在自己的 `transformPreference` 处把数据截断，外层收不到。

```swift
BYScrollView(isolatesNestedChanges: false) {
    VStack {
        BYScrollView(isolatesNestedChanges: false) { innerContent }
            .byContentOffsetChange { innerOffset in
                // 内层自己的回调，正常触发
            }
    }
}
.byContentOffsetPreferenceChange { dic in
    // dic 包含外层和内层两个 ID
}
```

### 父视图平级聚合

挂在父视图上，聚合所有**平级**子 `BYScrollView` 的尺寸/偏移。

```swift
func byScrollViewGeometryAggregate(
    onSizeChange: @escaping ([UUID: CGSize]) -> Void = { _ in },
    onOffsetChange: @escaping ([UUID: CGPoint]) -> Void = { _ in }
) -> some View
```

```swift
VStack {
    BYScrollView(byID: id1) { content1 }
    BYScrollView(byID: id2) { content2 }
}
.byScrollViewGeometryAggregate(
    onSizeChange: { dic in
        // dic[id1], dic[id2]
    },
    onOffsetChange: { dic in
        // dic[id1], dic[id2]
    }
)
```

> **与 `byNestedIsolation` 的关系**：平级聚合不受隔离影响——每个实例向上传播的始终是 `[自己ID: 值]`，父视图自然合并。隔离只影响"外层能否看到内层数据"，不影响平级之间。

### 刷新 / 加载（byRefresh）

```swift
func byRefresh(
    refreshThreshold: CGFloat,          // 下拉触发刷新的距离，默认 80
    loadMoreThreshold: CGFloat,         // 到底后继续上拉的触发距离，默认 24
    showsFooterWhenContentFits: Bool,   // 内容不足一屏时是否显示 Footer，默认 false
    autoRefreshOnAppear: Bool,          // 进入页面即自动刷新，默认 false
    hasMore: Bool,                      // 是否还有更多（false 显示"没有更多"）
    onRefresh: (() async -> Void)?,     // 下拉刷新回调
    onLoadMore: (() async -> Void)?     // 上拉加载回调；传 nil 时 Footer 整块不渲染
) -> some View
```

要点：

- `.byRefresh` 会接管当前实例的 `byGeometryChange`；需要同时监听几何时用返回容器的 `.onScrollGeometry { }` 追加。
- `onRefresh` / `onLoadMore` 均支持 async，内部会自动在刷新/加载期间 `await` 完成后复位状态。
- `hasMore = false` 显示"没有更多"，重新置 `true` 自动恢复加载能力（对应 MJRefresh `resetNoMoreData()`）。
- **不传 `onLoadMore`（`nil`）时 Footer 整块不渲染**，只做下拉刷新也不会出现"上拉加载更多"页脚。
- `autoRefreshOnAppear = true` 时，视图每次 `onAppear` 自动进入 `.refreshing` 并执行 `onRefresh`，无需手动下拉（对应 MJRefresh `beginRefreshing()`）；默认 `false` 由用户手动触发。

### 自定义刷头 / 页脚

```swift
func byRefreshHeader<Header: View>(
    @ViewBuilder _ header: @escaping (BYRefreshState, CGFloat) -> Header
) -> some View

func byLoadMoreFooter<Footer: View>(
    @ViewBuilder _ footer: @escaping (BYLoadMoreState) -> Footer
) -> some View
```

刷头回调参数 `(state: BYRefreshState, progress: CGFloat)`：

- `state` 驱动文案：`.idle` / `.pulling` / `.armed` / `.refreshing`
- `progress`（0~1）驱动箭头旋转 / 动画

页脚回调参数 `state: BYLoadMoreState`：`.idle` / `.armed` / `.loading` / `.noMore`。

---

## 状态机（交互时序，禁止随意改动）

下拉刷新与上拉加载的统一 Driver（`BYRefreshDriver`），交互时序经过多轮真机调试确定：

1. **Header 达阈值只进 `.armed`，必须松手才刷新**。松手判断用 `lastOverscroll`，不重读未经校准的 UIKit offset。
2. **达阈值后反向拖回阈值以内，立即恢复 `.pulling`**。
3. 刷新悬停：`updatePinnedInset` 每帧动态补偿，恒满足 `topInset + overscroll = refreshThreshold`，列表"挂住"呈现 MJRefresh 式悬停。
4. 刷新结束两阶段：先 `0.28s` 让 Header 跟随 ScrollView 移出屏幕，再复位 `idle`；保留负偏移，下一次下拉时无动画复位。
5. **Footer 同样松手触发**：仅 `scrollView.isDragging` 时进入 `.armed`，底部 Bounce overscroll 超过 `loadMoreThreshold` 后在松手时加载；`wasAtBottom` 标记防止停在底部重复触发。
6. Footer 高度固定 44pt，**严禁用 `Color.clear` / `Spacer` 额外撑高 contentSize**；显示与否由 `shouldShowFooter` 决定是否参与布局。**不传 `onLoadMore`（`nil`）时整块不渲染**，只做下拉刷新也不会出现"上拉加载更多"页脚。
7. `hasMore = false` 显示"没有更多"，重新置 `true` 自动恢复加载能力（对应 MJRefresh `resetNoMoreData()`）。

---

## 使用示例

### 示例 1：导航栏渐变（监听偏移）

```swift
struct NavBarGradientView: View {
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        BYScrollView {
            LazyVStack {
                ForEach(0..<50, id: \.self) { i in
                    Text("Row \(i)").padding()
                }
            }
        }
        .byContentOffsetChange { offset in
            scrollOffset = offset.y
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white)
                .opacity(min(max(scrollOffset / 100, 0), 1))
                .frame(height: 44)
        }
    }
}
```

### 示例 2：多实例联动（监听所有实例的偏移）

```swift
struct MultiScrollView: View {
    let id1 = UUID()
    let id2 = UUID()

    var body: some View {
        VStack {
            BYScrollView(byID: id1) { content1 }
                .frame(height: 200)
            BYScrollView(byID: id2) { content2 }
                .frame(height: 200)
        }
        .byScrollViewGeometryAggregate(onOffsetChange: { dic in
            if let offset1 = dic[id1], let offset2 = dic[id2] {
                print("id1 offset: \(offset1), id2 offset: \(offset2)")
            }
        })
    }
}
```

### 示例 3：嵌套聚合

```swift
BYScrollView(isolatesNestedChanges: false) {
    VStack {
        Text("Outer content")
        BYScrollView(isolatesNestedChanges: false) {
            Text("Inner content")
        }
    }
}
.byContentOffsetPreferenceChange { dic in
    // dic 含外层与内层两个 UUID 的 offset
}
```

### 示例 4：iOS 18+ 完整几何

```swift
if #available(iOS 18.0, *) {
    BYScrollView { content }
        .byFullGeometryChange { geometry in
            // contentInsets / visibleRect / bounds 等
        }
}
```

---

## 版本兼容

| 系统版本 | 测量方式 | `byGeometryChange` 字段 |
|---|---|---|
| iOS 15–17 | `GeometryReader + PreferenceKey` | `contentOffset` / `contentSize` / `containerSize` ✅ |
| iOS 18+ | `onScrollGeometryChange` | 同上 ✅ |
| iOS 18+ | 额外暴露 | `byFullGeometryChange` 提供完整 `ScrollGeometry` |

- `BYScrollGeometry` 的三个字段在所有支持版本上精度一致，调用者无需区分版本
- `byFullGeometryChange` 需要调用方显式处理版本差异（`@available`）

---

## 性能设计

- 容器只持有 Driver，**不订阅**其逐帧 `@Published`；Header / Footer 为独立**叶子视图**各自订阅，滚动中业务列表不会被逐帧重建。
- 高频几何写入引用类型 `@State` Store，去重不触发 body 重建。
- 首帧采样 `baseOffset`，之后不重置；手势判断一律用校准后的 `lastOverscroll`。
- 未接 `.byRefresh` 时探针不挂载，零开销。

---

## 注意事项

### 1. 嵌套聚合需内外层都传 `false`

若内层保持默认 `isolatesNestedChanges = true`，它会在自己的 `transformPreference` 处把数据截断，外层收不到内层数据。

```swift
// ✅ 正确：内外层都传 false
BYScrollView(isolatesNestedChanges: false) {
    BYScrollView(isolatesNestedChanges: false) { inner }
}

// ❌ 错误：内层保持默认 true，外层收不到内层数据
BYScrollView(isolatesNestedChanges: false) {
    BYScrollView { inner }   // 默认 true，截断了
}
```

### 2. 去重机制

- 单实例回调（`byContentSizeChange` / `byContentOffsetChange`）：内部按值比较去重
- 字典回调 / 聚合：字典变化时触发，同值不回调
- `byGeometryChange`：用 `lastReportedStore.geometry` 去重
- `byFullGeometryChange`：依赖 `onScrollGeometryChange` 内部的 `ScrollGeometry: Equatable` 比较

### 3. 主线程

`BYScrollView` 标注 `@MainActor`，所有回调在主线程执行。

### 4. body 重建

iOS 18 分支的 `ios18Geometry` 是 `@State`，每次几何变化会触发一次 body 重建。对于轻量 `contentView` 可接受；若 `contentView` 较重且不需要字典回调/父视图聚合，需关注此开销。

### 5. PreferenceKey 可见性

`BYScrollViewContentSizePreferenceKey` / `BYScrollViewContentOffsetPreferenceKey` 标为 internal（非 private），供父视图的 `byScrollViewGeometryAggregate` 引用。`BYScrollViewContainerSizePreferenceKey` 为 private，仅组件内部使用。

### 6. Package 导入需 `import BYScrollView`

使用 SPM / CocoaPods 导入时，每个用到库类型的文件顶部需 `import BYScrollView`（拷贝源码方式无需）。

---

## 相关类型

| 类型 | 可见性 | 说明 |
|---|---|---|
| `BYScrollView<BYContent>` | public | 主组件 |
| `BYScrollGeometry` | public | 跨版本统一几何模型 |
| `BYRefreshState` / `BYLoadMoreState` | public | 刷新 / 加载状态枚举 |
| `BYScrollViewContentSizePreferenceKey` | internal | 承载尺寸字典 |
| `BYScrollViewContentOffsetPreferenceKey` | internal | 承载偏移字典 |
| `BYScrollViewContainerSizePreferenceKey` | private | 承载容器尺寸 |
| `BYScrollViewLastReportedStore` | private | 去重存储（引用类型） |
| `BYScrollViewFallbackState` | private | iOS 15 容器尺寸缓存（引用类型） |
| `BYScrollViewGeometryAggregator` | internal | 父视图聚合 ViewModifier |

---

## 测试

`BYRefreshScrollViewTests` 内含 17 个状态机单元测试（`@MainActor`），覆盖：阈值判定、松手触发、反向取消、手势取消、悬停补偿、刷新复位、Footer 短列表 / 高度 / 未拖动不 armed / noMore 切换。当前工程 17/17 通过。

另有 `BYScrollViewDemo` 示例工程，含 10 个功能演示页（基础滚动 / 几何监听 / 多实例聚合 / 嵌套隔离 / 列表刷新 / 自定义刷头页脚 / 短列表 Footer / 没有更多 / 进入即刷新 / iOS 18 完整几何），以本地 Package 方式导入本库。
