//
//  FullGeometryDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 9：完整几何（iOS 18+）。
//  byFullGeometryChange 透传原生 ScrollGeometry，
//  展示 contentInsets / visibleRect / bounds 等 iOS 15–17 拿不到的字段。
//

import SwiftUI
import BYScrollView

struct FullGeometryDemo: View {
    @State private var geo: FullGeoSnapshot?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("iOS 18+ 原生 ScrollGeometry 完整字段")
                    .font(.subheadline.weight(.medium))

                row("contentOffset", geo.map { "(\(fmt($0.contentOffset.x)), \(fmt($0.contentOffset.y)))" } ?? "—")
                row("contentSize", geo.map { "\(fmt($0.contentSize.width)) × \(fmt($0.contentSize.height))" } ?? "—")
                row("containerSize", geo.map { "\(fmt($0.containerSize.width)) × \(fmt($0.containerSize.height))" } ?? "—")
                row("contentInsets", geo.map { "top \(fmt($0.contentInsets.top))" } ?? "—")
                row("visibleRect", geo.map { "(\(fmt($0.visibleRect.origin.x)), \(fmt($0.visibleRect.origin.y)), \(fmt($0.visibleRect.size.width)), \(fmt($0.visibleRect.size.height)))" } ?? "—")
                row("bounds", geo.map { "(\(fmt($0.bounds.origin.x)), \(fmt($0.bounds.origin.y)), \(fmt($0.bounds.size.width)), \(fmt($0.bounds.size.height)))" } ?? "—")
            }
            .font(.caption.monospaced())
            .padding(12)
            .background(
                Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .padding()

            Group {
                if #available(iOS 18.0, *) {
                    BYScrollView(axes: .vertical, showsIndicators: true) {
                        LazyVStack(spacing: 10) {
                            ForEach(0..<80, id: \.self) { i in
                                Text("完整几何行 \(i)")
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
                    .byFullGeometryChange { snapshot in
                        geo = FullGeoSnapshot(snapshot)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone.slash")
                            .font(.largeTitle)

                        Text("本页依赖 iOS 18+ 的 ScrollGeometry，当前系统无法演示。")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("完整几何（iOS 18+）")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fmt(_ v: CGFloat) -> String {
        String(format: "%.1f", v)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .foregroundStyle(.secondary)
                .frame(width: 104, alignment: .leading)
            Text(value)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 只读快照

/// ScrollGeometry 的纯值快照，避免非 iOS 18 分支引用该类型。
private struct FullGeoSnapshot {
    var contentOffset = CGPoint.zero
    var contentSize = CGSize.zero
    var containerSize = CGSize.zero
    var contentInsets = EdgeInsets()
    var visibleRect = CGRect.zero
    var bounds = CGRect.zero

    @available(iOS 18.0, *)
    init(_ geo: ScrollGeometry) {
        contentOffset = geo.contentOffset
        contentSize = geo.contentSize
        containerSize = geo.containerSize
        contentInsets = geo.contentInsets
        visibleRect = geo.visibleRect
        bounds = geo.bounds
    }
}

#Preview {
    NavigationStack {
        FullGeometryDemo()
    }
}
