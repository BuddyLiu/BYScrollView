//
//  BasicScrollDemo.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 1：基础滚动。
//  垂直 + 水平两个 BYScrollView，演示 axes 与 showsIndicators。
//

import SwiftUI

struct BasicScrollDemo: View {
    @State private var showsIndicators = true

    private let cardColors: [Color] = [.blue, .purple, .orange, .pink, .teal]

    var body: some View {
        VStack(spacing: 0) {
            Toggle("显示滚动指示条（showsIndicators）", isOn: $showsIndicators)
                .padding()

            BYScrollView(axes: .vertical, showsIndicators: showsIndicators) {
                LazyVStack(spacing: 10) {
                    ForEach(0..<60, id: \.self) { i in
                        HStack {
                            Text("第 \(i) 行")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(
                            Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))

            Divider()

            Text("横向滚动")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top])

            BYScrollView(axes: .horizontal, showsIndicators: showsIndicators) {
                HStack(spacing: 12) {
                    ForEach(0..<20, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardColors[i % cardColors.count].opacity(0.7))
                            .frame(width: 120, height: 90)
                            .overlay(
                                Text("卡片 \(i)")
                                    .foregroundStyle(.white)
                                    .font(.subheadline.weight(.semibold))
                            )
                    }
                }
                .padding()
            }
            .frame(height: 120)
        }
        .navigationTitle("基础滚动")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BasicScrollDemo()
    }
}
