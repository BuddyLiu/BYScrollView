# BYScrollView

> 一个可感知内容尺寸与滚动偏移的 SwiftUI `ScrollView` 封装，跨 iOS 15+ 提供语义一致的滚动几何观测能力。

## 目录

- [安装](#安装)
- [特性](#特性)
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
- [使用示例](#使用示例)
- [版本兼容](#版本兼容)
- [注意事项](#注意事项)

---

## 安装

### Swift Package Manager

在 Xcode 中：`File → Add Packages...` → 输入地址 `https://github.com/BuddyLiu/BYScrollView.git` → 版本规则选择 `Up to Next Major 1.0.0` → 添加 `BYScrollView` 到 target。

或直接在 `Package.swift` 中声明依赖：

```swift
dependencies: [
    .package(url: "https://github.com/BuddyLiu/BYScrollView.git", from: "1.0.0")
]
```

### CocoaPods

在 `Podfile` 中：

```ruby
pod 'BYScrollView', :git => 'https://github.com/BuddyLiu/BYScrollView.git', :tag => '1.0.0'
```

> 也可以直接引用指定 tag 或 commit：`:tag => '1.0.0'` / `:commit => 'xxxxxxx'`。
> 提交到 [CocoaPods 公共 spec 仓库](https://trunk.cocoapods.org) 后，即可直接 `pod 'BYScrollView'`。

两个包管理器共用同一份源码（`Sources/BYScrollView/`），API 完全一致。

---

## 特性

| 特性 | 说明 |
|---|---|
| **跨版本语义统一** | iOS 15–17 用 `GeometryReader + PreferenceKey` 测量；iOS 18+ 用原生 `onScrollGeometryChange`。对外暴露的 `contentOffset` / `contentSize` / `containerSize` 两端精度一致 |
| **三层观测 API** | 单实例回调、多实例字典回调、父视图平级聚合，覆盖单点与多实例场景 |
| **嵌套隔离可控** | 默认每层只回调本层数据；需要嵌套聚合时内外层显式传 `false` |
| **去重不触发重建** | 高频写入的"上次上报值"用引用类型 + `@State` 持有，写入内部字段不驱动 body 重建 |
| **完整几何（iOS 18+）** | 额外暴露原生 `ScrollGeometry`，含 `contentInsets` / `visibleRect` / `bounds` 等 iOS 15–17 无法精确获取的字段 |

---

## 快速开始

```swift
import SwiftUI
import BYScrollView

struct ContentView: View {
    var body: some View {
        BYScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<100, id: \.self) { i in
                    Text("Item \(i)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                }
            }
            .padding()
        }
        .byGeometryChange { geo in
            // geo.contentOffset / geo.contentSize / geo.containerSize
            print("offset: \(geo.contentOffset), size: \(geo.contentSize)")
        }
    }
}
```

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

---

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

---

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

---

### 跨版本统一几何

一次性拿到 `contentOffset` / `contentSize` / `containerSize` 三个字段，调用者无需 `#available` 判断。

```swift
func byGeometryChange(_ param: @escaping (BYScrollGeometry) -> Void) -> BYScrollView<BYContent>
```

触发时机：`size` / `offset` / `containerSize` 任一更新且合成结果与上次不同。用 `lastReportedStore.geometry` 去重，同一快照只回调一次。

数据源：

- iOS 18+：直接用 `ios18Geometry`（已含完整三个字段）
- iOS 15–17：用 `lastReportedStore` + `fallbackState` 组合

---

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

---

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

---

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

---

## 相关类型

| 类型 | 可见性 | 说明 |
|---|---|---|
| `BYScrollView<BYContent>` | public | 主组件 |
| `BYScrollGeometry` | public | 跨版本统一几何模型 |
| `BYScrollViewContentSizePreferenceKey` | internal | 承载尺寸字典 |
| `BYScrollViewContentOffsetPreferenceKey` | internal | 承载偏移字典 |
| `BYScrollViewContainerSizePreferenceKey` | private | 承载容器尺寸 |
| `BYScrollViewLastReportedStore` | private | 去重存储（引用类型） |
| `BYScrollViewFallbackState` | private | iOS 15 容器尺寸缓存（引用类型） |
| `BYScrollViewGeometryAggregator` | internal | 父视图聚合 ViewModifier |