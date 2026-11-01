//
//  BYScrollViewGeometryStore.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  内部状态存储：去重缓存、iOS 18 几何快照、轻量 emitter、宿主 UIScrollView 探针。
//  全部为引用类型，避免滚动期间高频更新触发 body 重建。
//

import SwiftUI
import Combine
import UIKit

// MARK: - 内部状态存储

/// 引用类型：`@State` 只在 wrappedValue 被整体重写时触发视图失效，
/// 修改 class 内部字段不会。此处存储的去重值不驱动 UI，用 class
/// 避免滚动期间每次偏移变化都重建 body。
@MainActor
final class BYScrollViewLastReportedStore {
    var size: CGSize?
    var offset: CGPoint?
    /// 上一次已回调的完整几何快照，用于 `publishGeometryIfReady` 去重。
    var geometry: BYScrollGeometry?
}

/// iOS 18 原生几何快照。引用类型避免主 BYScrollView 订阅逐帧更新。
@MainActor
final class BYScrollViewGeometryStore: ObservableObject {
    @Published var geometry: BYScrollGeometry?
}

/// 独立订阅几何快照并向上发 Preference；滚动帧不重建用户的滚动内容。
@MainActor
struct BYScrollViewGeometryPreferenceEmitter: View {
    let id: UUID
    @ObservedObject var store: BYScrollViewGeometryStore

    var body: some View {
        let geometry = store.geometry
        Color.clear
            .preference(
                key: BYScrollViewContentSizePreferenceKey.self,
                value: geometry.map { [id: $0.contentSize] } ?? [:]
            )
            .preference(
                key: BYScrollViewContentOffsetPreferenceKey.self,
                value: geometry.map { [id: $0.contentOffset] } ?? [:]
            )
            .preference(
                key: BYScrollViewContainerSizePreferenceKey.self,
                value: geometry?.containerSize ?? .zero
            )
    }
}

/// 容器尺寸缓存。引用类型，避免 `onPreferenceChange` 内写入触发重建。
@MainActor
final class BYScrollViewFallbackState {
    var containerSize: CGSize?
}

// MARK: - 宿主 UIScrollView 探针

/// 探针：零尺寸透明 UIView，挂到滚动内容上，沿 superview 链向上找宿主 `UIScrollView`。
///
/// SwiftUI `ScrollView` 在 UIKit 层面是 `_UIScrollViewHostingView` 包着一个真实的
/// `UIScrollView`。刷新悬停要改 `contentInset.top`（MJRefresh 同款机制），必须先拿到
/// 这个宿主。探针放在滚动内容内部，它的 superview 链一定经过宿主 UIScrollView，
/// 查找深度 20 足够覆盖 SwiftUI 的嵌套层级。
struct BYScrollViewHostFinder: UIViewRepresentable {
    let onFound: (UIScrollView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.isHidden = true
        DispatchQueue.main.async { [weak view] in
            guard let view else { return }
            var node = view.superview
            for _ in 0..<20 {
                guard let current = node else { break }
                if let sv = current as? UIScrollView {
                    onFound(sv)
                    return
                }
                node = current.superview
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
