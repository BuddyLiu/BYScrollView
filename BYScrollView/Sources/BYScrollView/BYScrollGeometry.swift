//
//  BYScrollGeometry.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  跨 iOS 15+ 语义统一的滚动几何快照模型。
//

import SwiftUI

/// 跨 iOS 15+ 语义一致的滚动几何快照。
/// `contentOffset` / `contentSize` / `containerSize` 在所有支持版本上精度一致。
///
/// 不包含 `contentInsets` / `visibleRect` / `bounds`：这些字段在 iOS 15–17
/// 无法精确获取，放进统一接口会让调用者误以为跨版本可信。
/// 需要时请用 `byFullGeometryChange`（仅 iOS 18+）。
public struct BYScrollGeometry: Equatable {
    public var contentOffset: CGPoint
    public var contentSize: CGSize
    public var containerSize: CGSize

    public init(contentOffset: CGPoint, contentSize: CGSize, containerSize: CGSize) {
        self.contentOffset = contentOffset
        self.contentSize = contentSize
        self.containerSize = containerSize
    }
}
