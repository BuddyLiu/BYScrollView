//
//  DemoFeedModel.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  下拉刷新 / 上拉加载 Demo 共用的模拟分页数据源。
//

import Foundation
import Combine

/// 列表项。
struct DemoFeedItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let subtitle: String
}

/// 模拟网络分页数据源。
///
/// - `reload()`：下拉刷新，回到第一页，`hasMore` 复位为 true。
/// - `loadMore()`：上拉加载，追加下一页；到底后 `hasMore = false`。
@MainActor
final class DemoFeedModel: ObservableObject {
    @Published private(set) var items: [DemoFeedItem] = []
    @Published private(set) var hasMore = true

    private var page = 0
    private let pageSize = 12
    private let totalPages = 8

    /// 首次进入页面时加载第一页（幂等）。
    func loadInitialPage() async {
        guard items.isEmpty else { return }
        await reload()
    }

    func reload() async {
        try? await Task.sleep(nanoseconds: 600_000_000)
        page = 0
        items = makePage(page)
        hasMore = page + 1 < totalPages
    }

    func loadMore() async {
        guard hasMore else { return }
        try? await Task.sleep(nanoseconds: 600_000_000)
        page += 1
        items.append(contentsOf: makePage(page))
        hasMore = page + 1 < totalPages
    }

    private func makePage(_ page: Int) -> [DemoFeedItem] {
        let start = page * pageSize
        return (0..<pageSize).map { i in
            let n = start + i + 1
            return DemoFeedItem(
                id: n,
                title: "模拟条目 #\(n)",
                subtitle: "第 \(page + 1) 页 · 示例副标题"
            )
        }
    }
}
