//
//  ContentView.swift
//  BYScrollViewDemo
//
//  Created by bo.liu on 2026/11/1.
//
//  Demo 首页：列出所有功能演示页。
//

import SwiftUI

/// 一个 Demo 入口。
struct DemoEntry: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let destination: AnyView
}

struct ContentView: View {
    private let demos: [DemoEntry] = [
        DemoEntry(
            title: "基础滚动",
            subtitle: "垂直 / 水平，滚动指示条开关",
            icon: "scroll",
            destination: AnyView(BasicScrollDemo())
        ),
        DemoEntry(
            title: "几何监听",
            subtitle: "contentSize / contentOffset / BYScrollGeometry",
            icon: "ruler",
            destination: AnyView(GeometryObserverDemo())
        ),
        DemoEntry(
            title: "多实例聚合",
            subtitle: "父视图一次拿到全部平级子实例",
            icon: "square.grid.2x2",
            destination: AnyView(AggregateDemo())
        ),
        DemoEntry(
            title: "嵌套隔离",
            subtitle: "内层滚动不污染外层回调",
            icon: "square.stack.3d.up",
            destination: AnyView(NestedIsolationDemo())
        ),
        DemoEntry(
            title: "下拉刷新 + 上拉加载",
            subtitle: "MJRefresh 式交互时序",
            icon: "arrow.clockwise",
            destination: AnyView(FeedDemo())
        ),
        DemoEntry(
            title: "自定义刷头 / 页脚",
            subtitle: "byRefreshHeader / byLoadMoreFooter",
            icon: "paintpalette",
            destination: AnyView(CustomHeaderFooterDemo())
        ),
        DemoEntry(
            title: "短列表 Footer",
            subtitle: "showsFooterWhenContentFits",
            icon: "list.bullet.rectangle",
            destination: AnyView(ShortListFooterDemo())
        ),
        DemoEntry(
            title: "没有更多",
            subtitle: "hasMore 状态机",
            icon: "stop.circle",
            destination: AnyView(NoMoreDemo())
        ),
        DemoEntry(
            title: "进入即刷新",
            subtitle: "autoRefreshOnAppear 自动刷新",
            icon: "arrow.down.circle",
            destination: AnyView(AutoRefreshDemo())
        ),
        DemoEntry(
            title: "完整几何（iOS 18+）",
            subtitle: "byFullGeometryChange 原生 ScrollGeometry",
            icon: "iphone",
            destination: AnyView(FullGeometryDemo())
        ),
    ]

    var body: some View {
        NavigationStack {
            List(demos) { demo in
                NavigationLink {
                    demo.destination
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(demo.title)
                                .font(.body)
                            Text(demo.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: demo.icon)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .navigationTitle("BYScrollView Demo")
        }
    }
}

#Preview {
    ContentView()
}
