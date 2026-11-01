//
//  NoMoreDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 8：没有更多。
//  hasMore 状态机：false 时页脚显示"没有更多"，
//  下拉刷新重置为 true 后恢复加载能力。
//

import SwiftUI

struct NoMoreDemo: View {
    @State private var hasMore = false
    @State private var items: [Int] = Array(0..<20)

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("hasMore = \(hasMore ? "true" : "false")")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Text("初始无更多：页脚显示「没有更多」。下拉刷新会把 hasMore 重置为 true，重新具备加载能力。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .padding()

            BYScrollView(axes: .vertical, showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    ForEach(items, id: \.self) { i in
                        Text("条目 \(i)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                }
                .padding()
            }
            .byRefresh(
                hasMore: hasMore,
                onRefresh: {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    hasMore = true
                },
                onLoadMore: {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    items.append(contentsOf: items.count..<(items.count + 20))
                    hasMore = false
                }
            )
        }
        .navigationTitle("没有更多")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NoMoreDemo()
    }
}
