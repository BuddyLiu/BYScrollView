//
//  BYRefreshState.swift
//  BYScrollView
//
//  Created by bo.liu on 2026/10/16.
//
//  下拉刷新 / 上拉加载的状态枚举。
//

import Foundation

/// 下拉刷头的状态机。
public enum BYRefreshState: Equatable {
    case idle
    case pulling
    case armed
    case refreshing
}

/// 上拉加载 Footer 的状态机。
public enum BYLoadMoreState: Equatable {
    case idle
    case armed       // 达到加载阈值，等待松手
    case loading
    case noMore
}
