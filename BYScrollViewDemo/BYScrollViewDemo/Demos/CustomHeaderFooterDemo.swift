//
//  CustomHeaderFooterDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 6：自定义刷头 / 页脚。
//  byRefreshHeader / byLoadMoreFooter 替换默认 MJRefresh 样式 UI。
//

import SwiftUI

struct CustomHeaderFooterDemo: View {
    @StateObject private var model = DemoFeedModel()

    var body: some View {
        BYScrollView(axes: .vertical, showsIndicators: true) {
            LazyVStack(spacing: 8) {
                ForEach(model.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.body.weight(.medium))
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
            }
            .padding()
        }
        .byRefresh(
            refreshThreshold: 80,
            loadMoreThreshold: 24,
            hasMore: model.hasMore,
            onRefresh: { await model.reload() },
            onLoadMore: { await model.loadMore() }
        )
        .byRefreshHeader { state, progress in
            DemoCustomHeader(state: state, progress: progress)
        }
        .byLoadMoreFooter { state in
            DemoCustomFooter(state: state)
        }
        .onAppear {
            Task { await model.loadInitialPage() }
        }
        .navigationTitle("自定义刷头 / 页脚")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 自定义刷头

/// 红色胶囊样式的刷头，progress 由 Driver 换算为 0...1。
private struct DemoCustomHeader: View {
    let state: BYRefreshState
    let progress: CGFloat

    var body: some View {
        Group {
            switch state {
                case .idle:
                    Color.clear

                case .pulling:
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down")
                            .rotationEffect(.degrees(Double(min(max(progress, 0), 1)) * 180.0))

                        Text("下拉刷新")
                    }

                case .armed:
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up")

                        Text("松手刷新")
                    }

                case .refreshing:
                    HStack(spacing: 8) {
                        ProgressView()
                            .frame(width: 16, height: 16)

                        Text("刷新中...")
                    }
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.red.opacity(0.85))
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 自定义页脚

/// 与默认页脚结构相同、文字定制的 Footer。
private struct DemoCustomFooter: View {
    let state: BYLoadMoreState

    var body: some View {
        Group {
            switch state {
                case .idle:
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up")

                        Text("上拉加载更多")
                    }

                case .armed:
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down")

                        Text("松开加载")
                    }

                case .loading:
                    HStack(spacing: 8) {
                        ProgressView()
                            .frame(width: 16, height: 16)

                        Text("加载中...")
                    }

                case .noMore:
                    Text("全部加载完成")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        CustomHeaderFooterDemo()
    }
}
