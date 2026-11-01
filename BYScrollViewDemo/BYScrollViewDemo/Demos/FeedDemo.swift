//
//  FeedDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 5：下拉刷新 + 上拉加载。
//  MJRefresh 式交互时序：下拉到阈值松手刷新，上拉到底松手加载。
//

import SwiftUI

struct FeedDemo: View {
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
        .onAppear {
            Task { await model.loadInitialPage() }
        }
        .navigationTitle("下拉刷新 + 上拉加载")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FeedDemo()
    }
}
