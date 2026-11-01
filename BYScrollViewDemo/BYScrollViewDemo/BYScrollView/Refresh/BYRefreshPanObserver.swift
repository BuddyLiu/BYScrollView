//
//  BYRefreshPanObserver.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  监听 UIScrollView 的真实拖动结束事件，负责松手触发判断。
//

import UIKit

/// 监听 UIScrollView 的真实拖动结束事件。
///
/// 刷新与加载都必须**松手才触发**，不能在下拉/上拉过程中直接触发。
/// 通过底层 `UIScrollView.panGestureRecognizer` 监听真实手势结束：
/// - `.ended`：交给 Driver 判断是否满足刷新 / 加载条件。
/// - `.cancelled` / `.failed`：不触发刷新 / 加载。
@MainActor
final class BYRefreshPanObserver: NSObject {

    weak var driver: BYRefreshDriver?

    init(driver: BYRefreshDriver) {
        self.driver = driver
    }

    @objc func handle(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                driver?.handlePanEnded()

            case .cancelled, .failed:
                driver?.handlePanCancelled()

            default:
                break
        }
    }
}
