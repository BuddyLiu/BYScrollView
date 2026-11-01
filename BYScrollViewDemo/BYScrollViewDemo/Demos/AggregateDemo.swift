//
//  AggregateDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 3：多实例平级聚合。
//  两个并排 BYScrollView 各自带 byID，父视图 byScrollViewGeometryAggregate 一次拿到全部。
//

import SwiftUI

struct AggregateDemo: View {
    @State private var sizes: [UUID: CGSize] = [:]
    @State private var offsets: [UUID: CGPoint] = [:]

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("父视图聚合 \(sizes.count) 个平级实例")
                    .font(.subheadline.weight(.medium))
                if sizes.isEmpty {
                    Text("滚动任意列表后读数会出现在这里")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach([DemoIDs.left, DemoIDs.right], id: \.self) { id in
                        let size = sizes[id].map {
                            String(format: "%.0f×%.0f", $0.width, $0.height)
                        } ?? "—"
                        let offset = offsets[id].map {
                            String(format: "(%.0f, %.0f)", $0.x, $0.y)
                        } ?? "—"
                        Text("\(DemoIDs.shortName(id))  size \(size)  offset \(offset)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .padding(.horizontal)

            HStack(spacing: 10) {
                BYScrollView(byID: DemoIDs.left, axes: .vertical, showsIndicators: true) {
                    VStack(spacing: 8) {
                        ForEach(0..<30, id: \.self) { i in
                            Text("左列表 \(i)")
                                .font(.footnote)
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(
                                    Color.red.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                    }
                    .padding(8)
                }
                .frame(maxWidth: .infinity)

                BYScrollView(byID: DemoIDs.right, axes: .vertical, showsIndicators: true) {
                    VStack(spacing: 8) {
                        ForEach(0..<30, id: \.self) { i in
                            Text("右列表 \(i)")
                                .font(.footnote)
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(
                                    Color.blue.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                    }
                    .padding(8)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
        .padding(.top)
        .navigationTitle("多实例聚合")
        .navigationBarTitleDisplayMode(.inline)
        .byScrollViewGeometryAggregate(
            onSizeChange: { sizes = $0 },
            onOffsetChange: { offsets = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        AggregateDemo()
    }
}
