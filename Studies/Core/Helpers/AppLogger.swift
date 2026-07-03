//
//  AppLogger.swift
//  Studies
//

import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Studies"

    static let data = Logger(subsystem: subsystem, category: "data")           // リポジトリ・SwiftData関連
    static let session = Logger(subsystem: subsystem, category: "session")     // ストップウォッチ・セッション復元
    static let liveActivity = Logger(subsystem: subsystem, category: "liveActivity")
    static let widget = Logger(subsystem: subsystem, category: "widget")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
