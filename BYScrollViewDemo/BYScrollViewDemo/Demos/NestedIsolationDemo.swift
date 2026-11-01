//
//  NestedIsolationDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 4：嵌套隔离。
//  外层 BYScrollView 内嵌一个内层 BYScrollView，
//  isolatesNestedChanges 开关决定外层能否收到内层的数据。
//

import SwiftUI
import BYScrollView

struct NestedIsolationDemo: View {
    @State private var isolatesNestedChanges = true
    @State private var outerReceived: [UUID] = []

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle("外层隔离内层（isolatesNestedChanges）", isOn: $isolatesNestedChanges)

                Text("外层 byContentSizePreferenceChange 收到：")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(outerReceived.isEmpty ? "（暂无）" : outerReceived.map { DemoIDs.shortName($0) }.joined(separator: "、"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .padding(.horizontal)

            BYScrollView(byID: DemoIDs.outer, axes: .vertical, isolatesNestedChanges: isolatesNestedChanges) {
                VStack(spacing: 12) {
                    ForEach(0..<12, id: \.self) { i in
                        Text("外层行 \(i)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(
                                Color.indigo.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }

                    BYScrollView(byID: DemoIDs.inner, axes: .vertical, showsIndicators: true) {
                        VStack(spacing: 6) {
                            ForEach(0..<20, id: \.self) { i in
                                Text("内层行 \(i)")
                                    .font(.footnote)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(
                                        Color.green.opacity(0.2),
                                        in: RoundedRectangle(cornerRadius: 6)
                                    )
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.green.opacity(0.5))
                    )
                }
                .padding()
            }
            .byContentSizePreferenceChange { dic in
                outerReceived = Array(dic.keys)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .navigationTitle("嵌套隔离")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NestedIsolationDemo()
    }
}
