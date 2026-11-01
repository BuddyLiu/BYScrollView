//
//  AutoRefreshDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 10：进入即刷新。
//  autoRefreshOnAppear 置 true 后，进入页面自动进入 .refreshing，
//  无需手动下拉；默认 false，需用户显式开启。
//

import SwiftUI
import BYScrollView

struct AutoRefreshDemo: View {
    @StateObject private var model = DemoFeedModel()

    var body: some View {
        VStack(spacing: 0) {
            Text("autoRefreshOnAppear = true：进入页面自动刷新，无需手动下拉。返回再进入会再次触发。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(.tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .padding()

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
                autoRefreshOnAppear: true,
                hasMore: model.hasMore,
                onRefresh: { await model.reload() },
                onLoadMore: { await model.loadMore() }
            )
        }
        .navigationTitle("进入即刷新")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AutoRefreshDemo()
    }
}
