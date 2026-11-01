//
//  BYScrollViewPreview.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  组件 Preview 与使用示例。
//

import SwiftUI
import Combine

// MARK: - 1. 基础垂直滚动

struct BYPreview_Vertical: View {
    var body: some View {
        BYScrollView(axes: .vertical) {
            VStack(spacing: 12) {
                ForEach(0..<30, id: \.self) { i in
                    Text("垂直滚动 · 第 \(i) 行")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }
            }
            .padding()
        }
    }
}

// MARK: - 2. 横向滚动

struct BYPreview_Horizontal: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("横向 ScrollView").font(.headline)
            BYScrollView(axes: .horizontal) {
                HStack(spacing: 12) {
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: 140, height: 120)
                            .overlay(Text("卡片 \(i)"))
                    }
                }
                .padding()
            }
            .frame(height: 150)
            .border(Color.secondary, width: 0.5)
        }
        .padding()
    }
}

// MARK: - 3. 内容尺寸 / 偏移监听

struct BYPreview_GeometryListeners: View {
    @State private var size: CGSize = .zero
    @State private var offset: CGPoint = .zero

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("size: \(Int(size.width))×\(Int(size.height))")
                Spacer()
                Text("offset: \(Int(offset.x)),\(Int(offset.y))")
            }
            .font(.caption.monospaced())
            .padding(8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)

            BYScrollView(axes: .vertical) {
                VStack(spacing: 10) {
                    ForEach(0..<40, id: \.self) { i in
                        Text("监听行 \(i)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                    }
                }
                .padding()
            }
            .byContentSizeChange { size = $0 }
            .byContentOffsetChange { offset = $0 }
        }
        .padding()
    }
}

// MARK: - 4. 多实例平级聚合

struct BYPreview_Aggregate: View {
    @State private var sizes: [UUID: CGSize] = [:]
    @State private var offsets: [UUID: CGPoint] = [:]

    var body: some View {
        VStack(spacing: 12) {
            Text("已聚合 \(sizes.count) 个实例，偏移合计 \(Int(offsets.values.map(\.y).reduce(0, +)))")
                .font(.caption)

            HStack(spacing: 8) {
                BYScrollView(byID: PreviewAggregateIDs.first, axes: .vertical) {
                    VStack(spacing: 8) {
                        ForEach(0..<20, id: \.self) { i in
                            Text("左 \(i)").padding().background(Color.red.opacity(0.3))
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                BYScrollView(byID: PreviewAggregateIDs.second, axes: .vertical) {
                    VStack(spacing: 8) {
                        ForEach(0..<20, id: \.self) { i in
                            Text("右 \(i)").padding().background(Color.blue.opacity(0.3))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 280)
        }
        .padding()
        .byScrollViewGeometryAggregate(
            onSizeChange: { sizes = $0 },
            onOffsetChange: { offsets = $0 }
        )
    }
}

enum PreviewAggregateIDs {
    static let first = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")
    static let second = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")
}

// MARK: - 5. 嵌套滚动隔离

struct BYPreview_Nested: View {
    @State private var outerIDs: Set<UUID> = []

    var body: some View {
        BYScrollView(axes: .vertical, isolatesNestedChanges: true) {
            VStack(spacing: 12) {
                Text("外层默认隔离内层，只回调自己的 ID").font(.caption)

                BYScrollView(byID: PreviewAggregateIDs.first, axes: .vertical) {
                    VStack(spacing: 6) {
                        ForEach(0..<15, id: \.self) { i in
                            Text("内层行 \(i)").padding().background(Color.green.opacity(0.3))
                        }
                    }
                    .padding(6)
                }
                .frame(height: 160)
            }
            .padding()
        }
        .byContentSizePreferenceChange { outerIDs = Set($0.keys) }
        .byGeometryChange { _ in }
        // 内层单独监听自己收到的数据
        .overlay(alignment: .bottomLeading) {
            Text("外层收到 \(outerIDs.count) 个实例").font(.caption).padding(6)
        }
    }
}

// MARK: - 6. 下拉刷新 + 上拉加载（模拟数据）

struct BYPreview_Feed: View {
    @StateObject private var vm = BYPreview_FeedViewModel()

    var body: some View {
        BYScrollView(axes: .vertical) {
            LazyVStack(spacing: 12) {
                ForEach(vm.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
        .byRefresh(
            refreshThreshold: 80,
            loadMoreThreshold: 24,
            hasMore: vm.hasMore,
            onRefresh: { await vm.reload() },
            onLoadMore: { await vm.loadMore() }
        )
    }
}

// MARK: - 7. 短列表 Footer 显示控制

struct BYPreview_ShortList: View {
    @State private var forceFooter = false

    var body: some View {
        VStack(spacing: 12) {
            Toggle("内容不足一屏也显示 Footer", isOn: $forceFooter)

            BYScrollView(axes: .vertical) {
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { i in
                        Text("短列表第 \(i) 行")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                    }
                }
                .padding()
            }
            .byRefresh(
                refreshThreshold: 80,
                loadMoreThreshold: 24,
                showsFooterWhenContentFits: forceFooter,
                hasMore: true,
                onLoadMore: { try? await Task.sleep(nanoseconds: 500_000_000) }
            )
        }
        .padding()
    }
}

// MARK: - 8. 自定义 Header / Footer

struct BYPreview_CustomHeaderFooter: View {
    @StateObject private var vm = BYPreview_FeedViewModel()

    var body: some View {
        BYScrollView(axes: .vertical) {
            LazyVStack(spacing: 12) {
                ForEach(vm.items) { item in
                    Text(item.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                }
            }
            .padding()
        }
        .byRefresh(
            refreshThreshold: 80,
            loadMoreThreshold: 24,
            hasMore: vm.hasMore,
            onRefresh: { await vm.reload() },
            onLoadMore: { await vm.loadMore() }
        )
        .byRefreshHeader { state, progress in
            HStack(spacing: 10) {
                if state == .refreshing {
                    ProgressView().tint(.blue)
                } else {
                    Image(systemName: "arrow.down")
                        .rotationEffect(.degrees(progress * 180))
                        .foregroundStyle(.blue)
                }
                Text(state == .armed ? "释放立即刷新" : "自定义刷新提示")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .padding(6)
            .background(Color.blue.opacity(0.12), in: Capsule())
        }
        .byLoadMoreFooter { state in
            Group {
                switch state {
                    case .loading:
                        HStack(spacing: 8) {
                            ProgressView().tint(.green)
                            Text("自定义加载中...")
                        }
                    case .noMore:
                        Text("自定义：没有更多啦")
                    default:
                        Text("自定义：上拉加载")
                }
            }
            .font(.footnote)
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 9. 没有更多数据

struct BYPreview_NoMore: View {
    @State private var hasMore = false
    @State private var items = (0..<15).map { BYPreview_FeedItem(id: $0, title: "第 \($0) 行", subtitle: "") }

    var body: some View {
        BYScrollView(axes: .vertical) {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    Text(item.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                }
            }
            .padding()
        }
        .byRefresh(
            refreshThreshold: 80,
            loadMoreThreshold: 24,
            hasMore: hasMore,
            onRefresh: {
                // 模拟刷新后恢复有更多数据
                hasMore = true
            },
            onLoadMore: { /* 已有更多时触发加载 */ }
        )
    }
}

// MARK: - Preview 用模拟数据

struct BYPreview_FeedItem: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
}

@MainActor
final class BYPreview_FeedViewModel: ObservableObject {
    @Published private(set) var items: [BYPreview_FeedItem] = []
    @Published private(set) var hasMore = true

    private var page = 1
    private let pageSize = 15

    func reload() async {
        try? await Task.sleep(nanoseconds: 600_000_000)
        items = (0..<pageSize).map {
            BYPreview_FeedItem(
                id: $0,
                title: "预览条目 #\($0 + 1)",
                subtitle: "下拉刷新后第一页"
            )
        }
        page = 1
        hasMore = true
    }

    func loadMore() async {
        try? await Task.sleep(nanoseconds: 600_000_000)
        let start = page * pageSize
        guard start < 80 else {
            hasMore = false
            return
        }
        items.append(contentsOf: (start..<min(start + pageSize, 80)).map {
            BYPreview_FeedItem(
                id: $0,
                title: "预览条目 #\($0 + 1)",
                subtitle: "第 \(page + 1) 页"
            )
        })
        page += 1
        hasMore = start + pageSize < 80
    }
}

#Preview("垂直滚动") { BYPreview_Vertical() }
#Preview("横向滚动") { BYPreview_Horizontal() }
#Preview("几何监听") { BYPreview_GeometryListeners() }
#Preview("多实例聚合") { BYPreview_Aggregate() }
#Preview("嵌套隔离") { BYPreview_Nested() }
#Preview("刷新 + 加载更多") { BYPreview_Feed() }
#Preview("短列表 Footer") { BYPreview_ShortList() }
#Preview("自定义 Header / Footer") { BYPreview_CustomHeaderFooter() }
#Preview("没有更多") { BYPreview_NoMore() }
