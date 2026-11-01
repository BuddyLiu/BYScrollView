//
//  BYDebug.swift
//  BYRefreshScrollView
//
//  Created by bo.liu on 2026/10/29.
//
//  临时真机诊断工具：把状态写进应用沙盒 Documents，
//  用 `devicectl device copy from` 拉出来分析。
//

#if DEBUG
import UIKit
import SwiftUI

final class BYDebug {
    static let shared = BYDebug()

    private let fileManager = FileManager.default
    private lazy var docURL: URL = {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    private var lastLogTime: Date = .distantPast

    /// 追加一行日志（每条目录下只保留最近 2000 行，避免无限增长）。
    func log(_ line: String, throttleMs: Int = 0) {
        let now = Date()
        if throttleMs > 0, now.timeIntervalSince(lastLogTime) * 1000 < Double(throttleMs) {
            return
        }
        lastLogTime = now
        let url = docURL.appendingPathComponent("bydebug.log")
        let line = "[\(timestamp())] \(line)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.data(using: .utf8)?.write(to: url)
        }
        // 简单截断：超过 4000 行就重写为最近一半
        if let text = try? String(contentsOf: url, encoding: .utf8),
           text.split(whereSeparator: \.isNewline).count > 4000 {
            let tail = text.split(whereSeparator: \.isNewline).suffix(2000).joined(separator: "\n")
            try? (tail + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// 抓取当前主窗口截图到 Documents/byshot.png。
    func captureScreenshot(_ name: String = "byshot") {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let window = windowScene.windows.first else {
            log("captureScreenshot: no window")
            return
        }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let url = docURL.appendingPathComponent("\(name).png")
        try? image.pngData()?.write(to: url)
        log("captureScreenshot \(name) saved \(Int(image.size.width))x\(Int(image.size.height))")
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
#endif
