//
// StudyTimeCharts.swift
// Studies
//
// 7-day / 30-day / 12-month 学習時間チャート
//

import SwiftUI
import Charts

struct StudyTimeCharts: View {
    @Environment(DIContainer.self) private var di
    @State private var span: ChartSpan = .sevenDays
    @State private var rows: [ChartRow] = []
    @State private var scrollPos: Date
    @State private var isLoading = false
    @State private var isScrollingToToday = false
    @State private var scrollProgress: Double = 0
    @State private var buttonPressed = false
    
    init() {
        let now = Date()
        let calendar = Calendar.current
        _scrollPos = State(initialValue: calendar.startOfDay(for: now))
    }
    
    var scrollPositionEnd: Date {
        let calendar = Calendar.current
        switch span {
        case .sevenDays, .thirtyDays:
            return scrollPos.addingTimeInterval(span.visibleLength)
        case .twelveMonths:
            // 月表示では月初から12ヶ月後の月末まで
            let scrollMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: scrollPos))!
            let endMonth = calendar.date(byAdding: .month, value: 12, to: scrollMonthStart)!
            return calendar.date(byAdding: .second, value: -1, to: endMonth) ?? endMonth
        }
    }
    
    var dateRangeString: String {
        let calendar = Calendar.current
        let (rangeStart, rangeEnd) = alignedVisibleRange()
        switch span {
        case .sevenDays, .thirtyDays:
            let endDisplay = calendar.date(byAdding: .day, value: -1, to: rangeEnd) ?? rangeEnd
            let startYear = calendar.component(.year, from: rangeStart)
            let startMonth = calendar.component(.month, from: rangeStart)
            let startDay = calendar.component(.day, from: rangeStart)
            let endYear = calendar.component(.year, from: endDisplay)
            let endMonth = calendar.component(.month, from: endDisplay)
            let endDay = calendar.component(.day, from: endDisplay)
            
            if startYear == endYear && startMonth == endMonth {
                return "\(startYear)年\(startMonth)月\(startDay)日〜\(endDay)日"
            } else if startYear == endYear {
                return "\(startYear)年\(startMonth)月\(startDay)日〜\(endMonth)月\(endDay)日"
            } else {
                return "\(startYear)年\(startMonth)月\(startDay)日〜\(endYear)年\(endMonth)月\(endDay)日"
            }
            
        case .twelveMonths:
            let endDisplay = calendar.date(byAdding: .month, value: -1, to: rangeEnd) ?? rangeEnd
            let startYear = calendar.component(.year, from: rangeStart)
            let startMonth = calendar.component(.month, from: rangeStart)
            let endYear = calendar.component(.year, from: endDisplay)
            let endMonth = calendar.component(.month, from: endDisplay)
            
            if startYear == endYear {
                return "\(startYear)年"
            } else {
                return "\(startYear)年\(startMonth)月〜\(endYear)年\(endMonth)月"
            }
        }
    }
    
    var averageStudyTimeInVisibleRange: Double {
        let calendar = Calendar.current
        let (rangeStart, rangeEnd) = alignedVisibleRange()
        
        // 表示範囲内のすべてのバケット（日または月）を生成
        var allBuckets: [Date] = []
        var current = rangeStart
        while current < rangeEnd {
            allBuckets.append(current)
            switch span {
            case .sevenDays, .thirtyDays:
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            case .twelveMonths:
                current = calendar.date(byAdding: .month, value: 1, to: current)!
            }
        }
        
        guard !allBuckets.isEmpty else { return 0 }
        
        // 表示範囲の行のみ集計
        let visibleRows = rows.filter { row in
            row.bucketDate >= rangeStart && row.bucketDate < rangeEnd
        }
        
        let totalsByBucket = Dictionary(grouping: visibleRows, by: { $0.bucketDate })
            .mapValues { bucketRows in
                bucketRows.reduce(0) { $0 + $1.durationMinutes }
            }
        
        // 0分のバケットも含めて平均を計算
        let totalMinutes = allBuckets.reduce(0.0) { total, date in
            total + (totalsByBucket[date] ?? 0.0)
        }
        
        return totalMinutes / Double(allBuckets.count)
    }
    
    // 表示範囲の合計学習時間
    var totalStudyTimeInVisibleRange: Double {
        let (rangeStart, rangeEnd) = alignedVisibleRange()
        
        let visibleRows = rows.filter { row in
            row.bucketDate >= rangeStart && row.bucketDate < rangeEnd
        }
        
        return visibleRows.reduce(0.0) { $0 + $1.durationMinutes }
    }
    
    // 「今日」ボタンの表示判定
    private var shouldShowTodayButton: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch span {
        case .sevenDays:
            // 今日が表示範囲に含まれているかチェック
            let todayStart = calendar.startOfDay(for: now)
            let visibleStart = scrollPos
            let visibleEnd = scrollPos.addingTimeInterval(span.visibleLength)
            return !(todayStart >= visibleStart && todayStart < visibleEnd)
            
        case .thirtyDays:
            // 今日が表示範囲に含まれているかチェック
            let todayStart = calendar.startOfDay(for: now)
            let visibleStart = scrollPos
            let visibleEnd = scrollPos.addingTimeInterval(span.visibleLength)
            return !(todayStart >= visibleStart && todayStart < visibleEnd)
            
        case .twelveMonths:
            // 今月が表示範囲に含まれているかチェック
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let visibleStart = calendar.date(from: calendar.dateComponents([.year, .month], from: scrollPos))!
            let visibleEnd = calendar.date(byAdding: .month, value: 12, to: visibleStart)!
            return !(currentMonthStart >= visibleStart && currentMonthStart < visibleEnd)
        }
    }
    
    // 「今日」の適切なスクロール位置を計算
    private func getTodayScrollPosition() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch span {
        case .sevenDays:
            // 今日から6日前の位置（今日が右端に来るように）
            let idealPos = calendar.date(byAdding: .day, value: -6, to: now) ?? now
            return calendar.startOfDay(for: idealPos)
            
        case .thirtyDays:
            // 今日から29日前の位置（今日が右端に来るように）
            let idealPos = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            return calendar.startOfDay(for: idealPos)
            
        case .twelveMonths:
            // 今月から11ヶ月前の位置（今月が右端に来るように）
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let idealPos = calendar.date(byAdding: .month, value: -11, to: currentMonthStart) ?? currentMonthStart
            return idealPos
        }
    }
    
    // 可視範囲を日・月境界に揃えて取得（終了は排他的）
    private func alignedVisibleRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        switch span {
        case .sevenDays:
            let start = calendar.startOfDay(for: scrollPos)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)
        case .thirtyDays:
            let start = calendar.startOfDay(for: scrollPos)
            let end = calendar.date(byAdding: .day, value: 30, to: start) ?? start
            return (start, end)
        case .twelveMonths:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: scrollPos))!
            let end = calendar.date(byAdding: .month, value: 12, to: start) ?? start
            return (start, end)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // スパン切替
                Picker("", selection: $span) {
                    Text("週").tag(ChartSpan.sevenDays)
                    Text("月").tag(ChartSpan.thirtyDays)
                    Text("年").tag(ChartSpan.twelveMonths)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 平均と合計を横並びで表示
                VStack(alignment: .leading, spacing: 8) {
                    // 平均時間と合計時間を横並びで表示
                    HStack(spacing: 24) {
                        // 平均時間表示
                        VStack(alignment: .leading, spacing: 4) {
                            Text("平均")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            formatDurationWithStyle(averageStudyTimeInVisibleRange)
                        }
                        
                        // 合計時間表示
                        VStack(alignment: .leading, spacing: 4) {
                            Text("合計")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            formatDurationWithStyle(totalStudyTimeInVisibleRange)
                        }
                    }
                    
                    // 日付表示のHStackを基準にした固定レイアウト
                    HStack {
                        Text(dateRangeString)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .overlay(
                        // ボタンを完全にオーバーレイとして配置（HStackのサイズに影響しない）
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    scrollPos = getTodayScrollPosition()
                                }
                                HapticFeedback.light()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar.circle.fill")
                                        .font(.system(size: 14))
                                    Text("今日")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: .blue.opacity(0.25), radius: 4, x: 0, y: 2)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .opacity(shouldShowTodayButton ? 1.0 : 0.0)
                            .scaleEffect(shouldShowTodayButton ? 1.0 : 0.8)
                            .allowsHitTesting(shouldShowTodayButton)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: shouldShowTodayButton)
                        }
                    )
                }
                .padding(.horizontal)
            }
            
            // チャート表示部分
            Group {
                if isLoading {
                    // ローディング中
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("読み込み中…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: 240)
                } else if rows.isEmpty {
                    // データがない場合
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("学習記録がありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("学習を開始すると、ここにグラフが表示されます")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: 240)
                } else {
                    // データがある場合
                    createChart()
                        .frame(height: 240)
                        .padding(.horizontal)
                }
            }
        }
        .task(id: span) { await loadData() }
    }
    
    @ViewBuilder
    private func createChart() -> some View {
        Chart(rows) { row in
            BarMark(
                x: .value("Period", row.bucketDate, unit: span.xUnit),
                y: .value("Minutes", row.durationMinutes)
            )
            .foregroundStyle(row.subjectColor)
        }
        .chartScrollableAxes(.horizontal)
        .chartScrollTargetBehavior(
            .valueAligned(matching: span.matching,
                          majorAlignment: .matching(span.majorAlignment))
        )
        .chartXVisibleDomain(length: span.visibleLength)
        .chartScrollPosition(x: $scrollPos)
        .chartXAxis {
            span.axisMarks
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(formatMinutesToHourMinute(minutes))
                            .font(.caption2)
                    }
                }
            }
        }
    }
    
    // MARK: - データ読み込み（全データ一括読み込み）
    private func loadData() async {
        await MainActor.run {
            isLoading = true
            rows = []
        }
        
        do {
            let manager = StudyChartDataManager(useCase: di.studyRecordUseCase)
            let subjects = try await di.subjectUseCase.getAllSubjects()
            
            // アクティブなデータのみ取得
            let (startDate, endDate) = span.fullDataRange()
            let baseRows = try await manager.fetchActiveSummarizedRows(
                for: StudyChartDataManager.Span(span),
                from: startDate,
                to: endDate
            )
            
            let newRows = baseRows.compactMap { base -> ChartRow? in
                guard let subject = subjects.first(where: { $0.id == base.subjectId }) else { return nil }
                return ChartRow(
                    id: base.id,
                    bucketDate: base.bucketDate,
                    subjectName: subject.name,
                    subjectColor: subject.color,
                    durationMinutes: base.duration / 60
                )
            }
            
            await MainActor.run {
                rows = newRows.sorted { $0.bucketDate < $1.bucketDate }
                isLoading = false
                adjustInitialScrollPosition()
            }
        } catch {
            await MainActor.run {
                print("Chart load error:", error)
                rows = []
                isLoading = false
            }
        }
    }
    
    // 初回読み込み後のスクロール位置調整
    @MainActor
    private func adjustInitialScrollPosition() {
        guard !rows.isEmpty else { return }
        
        let calendar = Calendar.current
        switch span {
        case .sevenDays:
            // 週表示: 最新データから1週間前の位置に設定
            if let latestDate = rows.map({ $0.bucketDate }).max() {
                let idealScrollPos = calendar.date(byAdding: .day, value: -6, to: latestDate) ?? latestDate
                scrollPos = calendar.startOfDay(for: idealScrollPos)
            }
            
        case .thirtyDays:
            // 月表示: 最新データから1ヶ月前の位置に設定
            if let latestDate = rows.map({ $0.bucketDate }).max() {
                let idealScrollPos = calendar.date(byAdding: .day, value: -29, to: latestDate) ?? latestDate
                scrollPos = calendar.startOfDay(for: idealScrollPos)
            }
            
        case .twelveMonths:
            // 年表示: 最新データから12ヶ月前の月初に設定
            if let latestDate = rows.map({ $0.bucketDate }).max() {
                let latestMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: latestDate))!
                let idealScrollPos = calendar.date(byAdding: .month, value: -11, to: latestMonthStart) ?? latestMonthStart
                scrollPos = idealScrollPos
            }
        }
    }
    
    // Helper Functions
    private func formatMinutesToHourMinute(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60
        
        if hours == 0 {
            return "\(remainingMinutes)m"
        } else if remainingMinutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h\(remainingMinutes)m"
        }
    }
    
    @ViewBuilder
    private func formatDurationWithStyle(_ minutes: Double) -> some View {
        let totalMinutes = Int(minutes.rounded())
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if hours > 0 {
                Text("\(hours)")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.primary)
                    .fontDesign(.rounded)
                Text("時間")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
                
                if mins > 0 {
                    Text("\(mins)")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.primary)
                        .fontDesign(.rounded)
                    Text("分")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                }
            } else {
                Text("\(mins)")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.primary)
                    .fontDesign(.rounded)
                Text("分")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Support Types
private struct ChartRow: Identifiable, Equatable {
    let id: UUID
    let bucketDate: Date
    let subjectName: String
    let subjectColor: Color
    let durationMinutes: TimeInterval
}

// MARK: - ChartSpan（シンプル版）
enum ChartSpan: CaseIterable {
    case sevenDays, thirtyDays, twelveMonths
    
    var xUnit: Calendar.Component {
        switch self {
        case .sevenDays, .thirtyDays: return .day
        case .twelveMonths: return .month
        }
    }
    
    var visibleLength: TimeInterval {
        let day = 86_400.0
        switch self {
        case .sevenDays: return day * 7
        case .thirtyDays: return day * 30
        case .twelveMonths: return day * 30 * 12
        }
    }
    
    // 全データ読み込み範囲
    func fullDataRange() -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .sevenDays, .thirtyDays:
            // 5年前から現在まで
            let start = calendar.date(byAdding: .year, value: -5, to: calendar.startOfDay(for: now))!
            return (start, now)
            
        case .twelveMonths:
            // 5年前から現在まで（月境界）
            let start = calendar.date(byAdding: .year, value: -5, to: calendar.startOfDay(for: now))!
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            return (start, end)
        }
    }
    
    var fullDateRange: ClosedRange<Date> {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .sevenDays:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            return start...now
        case .thirtyDays:
            let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
            return start...now
        case .twelveMonths:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let start = calendar.date(byAdding: .month, value: -11, to: monthStart)!
            let end = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            return start...end
        }
    }
    
    func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = self == .twelveMonths ? "yyyy-MM" : "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    var matching: DateComponents {
        switch self {
        case .sevenDays, .thirtyDays: return .init(hour: 0)
        case .twelveMonths: return .init(day: 1)
        }
    }
    
    var majorAlignment: DateComponents {
        switch self {
        case .sevenDays: return .init(weekday: 2)
        case .thirtyDays: return .init(day: 1)
        case .twelveMonths: return .init(month: 1)
        }
    }
    
    @AxisContentBuilder
    var axisMarks: some AxisContent {
        switch self {
        case .sevenDays:
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    let weekday = Calendar.current.component(.weekday, from: date)
                    let isMonday = (weekday == 2)
                    
                    AxisGridLine(stroke: StrokeStyle(
                        lineWidth: isMonday ? 1.0 : 0.5,
                        dash: isMonday ? [] : [2, 2]
                    ))
                    AxisTick()
                    AxisValueLabel {
                        Text(weekdayString(from: date))
                            .font(.caption2)
                    }
                }
            }
            
        case .thirtyDays:
            AxisMarks(values: .stride(by: .month)) { value in
                if let date = value.as(Date.self) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1.0))
                    AxisTick()
                }
            }
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    let weekday = Calendar.current.component(.weekday, from: date)
                    if weekday == 1 {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        AxisTick()
                        AxisValueLabel {
                            Text(dayOnlyString(from: date))
                                .font(.caption2)
                        }
                    }
                }
            }
            
        case .twelveMonths:
            AxisMarks(values: .stride(by: .year)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1.0))
            }
            AxisMarks(values: .stride(by: .month)) { value in
                if let date = value.as(Date.self) {
                    let month = Calendar.current.component(.month, from: date)
                    let isJanuary = (month == 1)
                    
                    AxisGridLine(stroke: StrokeStyle(
                        lineWidth: isJanuary ? 1.0 : 0.5,
                        dash: isJanuary ? [] : [2, 2]
                    ))
                    AxisTick()
                    AxisValueLabel {
                        Text(monthString(from: date))
                            .font(.caption2)
                    }
                }
            }
        }
    }
    
    private func weekdayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    private func monthString(from date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        return "\(month)月"
    }
    
    private func dayOnlyString(from date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)日"
    }
}

extension StudyChartDataManager.Span {
    init(_ chartSpan: ChartSpan) {
        switch chartSpan {
        case .sevenDays: self = .sevenDays
        case .thirtyDays: self = .thirtyDays
        case .twelveMonths: self = .twelveMonths
        }
    }
}

// MARK: - Preview
#Preview("週表示") {
    StudyTimeCharts()
        .environment(DIContainer.shared)
}

#Preview("月表示") {
    let view = StudyTimeCharts()
    return view
        .environment(DIContainer.shared)
}

#Preview("年表示") {
    let view = StudyTimeCharts()
        .environment(DIContainer.shared)
}
