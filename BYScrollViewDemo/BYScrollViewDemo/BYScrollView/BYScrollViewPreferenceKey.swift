//
//  BYScrollViewPreferenceKey.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  几何上报所用的 PreferenceKey，以及父视图平级聚合入口。
//

import SwiftUI

// MARK: - PreferenceKey

/// 承载各实例内容尺寸的字典，向上传播时按 UUID 合并。
/// 标为 internal（非 private）是因为父视图的 `byScrollViewGeometryAggregate` 需要引用它。
struct BYScrollViewContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGSize] = [:]

    static func reduce(value: inout [UUID: CGSize], nextValue: () -> [UUID: CGSize]) {
        value.merge(nextValue()) { $1 }
    }
}

/// 承载各实例滚动偏移的字典，语义同上。
struct BYScrollViewContentOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGPoint] = [:]

    static func reduce(value: inout [UUID: CGPoint], nextValue: () -> [UUID: CGPoint]) {
        value.merge(nextValue()) { $1 }
    }
}

/// 承载容器尺寸。两分支共用：
/// - iOS 15–17：来自 ScrollView 外层 GeometryReader
/// - iOS 18+：来自 `ios18Geometry.containerSize`
struct BYScrollViewContainerSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - 父视图平级聚合

/// 挂在父视图上，聚合子树内所有平级 `BYScrollView` 向上传播的尺寸/偏移字典。
struct BYScrollViewGeometryAggregator: ViewModifier {
    let onSizeChange: ([UUID: CGSize]) -> Void
    let onOffsetChange: ([UUID: CGPoint]) -> Void

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(BYScrollViewContentSizePreferenceKey.self, perform: onSizeChange)
            .onPreferenceChange(BYScrollViewContentOffsetPreferenceKey.self, perform: onOffsetChange)
    }
}

extension View {
    /// 挂在父视图上，聚合所有平级子 `BYScrollView` 的尺寸/偏移。
    ///
    /// 每个子实例向上传播 `[自己的ID: 值]`，父视图 reduce 后拿到全部平级实例：
    /// `[id1: ..., id2: ...]`。
    ///
    /// 与 `byNestedIsolation` 的关系：平级聚合不受隔离影响——每个实例向上
    /// 传播的始终是 `[自己ID: 值]`，父视图自然合并。隔离只影响"外层能否看到
    /// 内层数据"，不影响平级之间。
    public func byScrollViewGeometryAggregate(
        onSizeChange: @escaping ([UUID: CGSize]) -> Void = { _ in },
        onOffsetChange: @escaping ([UUID: CGPoint]) -> Void = { _ in }
    ) -> some View {
        modifier(BYScrollViewGeometryAggregator(
            onSizeChange: onSizeChange,
            onOffsetChange: onOffsetChange
        ))
    }
}
