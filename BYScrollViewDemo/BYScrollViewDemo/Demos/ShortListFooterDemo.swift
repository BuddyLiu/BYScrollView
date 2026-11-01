//
//  ShortListFooterDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 7：短列表 Footer。
//  showsFooterWhenContentFits 决定内容不足一屏时是否显示 Footer。
//

import SwiftUI
import BYScrollView

struct ShortListFooterDemo: View {
    @State private var showsFooterWhenContentFits = true
    @State private var count = 3

    var body: some View {
        VStack(spacing: 0) {
            Toggle("showsFooterWhenContentFits（不足一屏也显示 Footer）", isOn: $showsFooterWhenContentFits)
                .padding()

            BYScrollView(axes: .vertical, showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    ForEach(0..<count, id: \.self) { i in
                        Text("短列表行 \(i + 1)")
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
                loadMoreThreshold: 24,
                showsFooterWhenContentFits: showsFooterWhenContentFits,
                onLoadMore: {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    count += 3
                }
            )
        }
        .navigationTitle("短列表 Footer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ShortListFooterDemo()
    }
}
