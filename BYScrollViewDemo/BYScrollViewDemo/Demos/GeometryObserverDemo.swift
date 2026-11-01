//
//  GeometryObserverDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 2：几何监听。
//  byContentSizeChange / byContentOffsetChange / byGeometryChange 实时读数。
//

import SwiftUI

struct GeometryObserverDemo: View {
    @State private var contentSize: CGSize = .zero
    @State private var contentOffset: CGPoint = .zero
    @State private var geometry: BYScrollGeometry?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                row("contentSize", String(format: "%.0f × %.0f", contentSize.width, contentSize.height))
                row("contentOffset", String(format: "(%.1f, %.1f)", contentOffset.x, contentOffset.y))
                row("containerSize",
                    geometry.map { String(format: "%.0f × %.0f", $0.containerSize.width, $0.containerSize.height) }
                        ?? "—")
            }
            .font(.caption.monospaced())
            .padding(12)
            .background(
                Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .padding()

            BYScrollView(axes: .vertical, showsIndicators: true) {
                VStack(spacing: 10) {
                    ForEach(0..<80, id: \.self) { i in
                        Text("监听行 \(i)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                }
                .padding()
            }
            .byContentSizeChange { contentSize = $0 }
            .byContentOffsetChange { contentOffset = $0 }
            .byGeometryChange { geometry = $0 }
        }
        .navigationTitle("几何监听")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .foregroundStyle(.secondary)
                .frame(width: 108, alignment: .leading)
            Text(value)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    NavigationStack {
        GeometryObserverDemo()
    }
}
