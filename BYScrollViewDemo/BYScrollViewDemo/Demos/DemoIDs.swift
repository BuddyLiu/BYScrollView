//
//  DemoIDs.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  多实例 / 嵌套 Demo 的稳定实例 ID。
//  固定 UUID 便于在回调字典里辨识是哪个实例。
//

import Foundation

enum DemoIDs {
    static let left = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    static let right = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!
    static let outer = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000003")!
    static let inner = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000004")!

    /// 把一组 UUID 缩写为可读的短名（方便在回调里展示）。
    static func shortName(_ id: UUID) -> String {
        switch id {
            case left:  return "left"
            case right: return "right"
            case outer: return "outer"
            case inner: return "inner"
            default:    return String(id.uuidString.prefix(8))
        }
    }
}
