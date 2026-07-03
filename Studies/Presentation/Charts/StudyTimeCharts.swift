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
    @State private var selectedDate: Date? = nil
    @State private var lastHapticBucketDate: Date? = nil

    // 集計済みデータ（読み込み時に一度だけ構築し、スクロール中の再計算を避ける）
    @State private var sortedRowsForChart: [ChartRow] = []
    @State private var totalsByBucket: [Date: Double] = [:]
    @State private var rowsByBucket: [Date: [ChartRow]] = [:]

    // 初回ロード済みかどうか（trueの間はスパン切替時にスピナーを出さず、直前の表示位置を維持する）
    @State private var hasLoadedOnce = false
    // 直前に読み込んだスパン（切替時の表示位置維持の変換元として使用）
    @State private var lastLoadedSpan: ChartSpan = .sevenDays

    // Y軸の表示上限（現在の表示ページに合わせて静止後に再計算する）
    @State private var yAxisUpperBound: Double = 60
    // Y軸再計算のデバウンス用タスク（スクロール中は毎フレーム走らせず、静止を待って1回だけ実行する）
    @State private var yAxisRecalcTask: Task<Void, Never>?

    init() {
        _scrollPos = State(initialValue: Self.todayScrollPosition(for: .sevenDays))
    }

    // 「今日」を含むページの先頭位置を計算（インスタンス生成前や初期値計算にも使えるようstatic化）
    // 週表示は今週の先頭、月・年表示は今日／今月が右端に来る位置を返す
    private static func todayScrollPosition(for span: ChartSpan) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch span {
        case .sevenDays:
            // ヘルスケア準拠: 今日を含む「今週」の先頭を表示する
            // （dateInterval(of: .weekOfYear) はシステム設定の週始まりの曜日 Calendar.firstWeekday に従う）
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        case .thirtyDays:
            let idealPos = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            return calendar.startOfDay(for: idealPos)
        case .twelveMonths:
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return calendar.date(byAdding: .month, value: -11, to: currentMonthStart) ?? currentMonthStart
        }
    }

    // 年表示は月ごとに日数が異なる（うるう年など）ため、スクロール位置（月初）を基準に
    // 実際の12ヶ月分の長さを都度計算する。週・月表示は固定長のまま。
    private var currentVisibleLength: TimeInterval {
        switch span {
        case .sevenDays, .thirtyDays:
            return span.visibleLength
        case .twelveMonths:
            let calendar = Calendar.current
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: scrollPos)) ?? scrollPos
            let monthEnd = calendar.date(byAdding: .month, value: 12, to: monthStart) ?? monthStart.addingTimeInterval(span.visibleLength)
            return monthEnd.timeIntervalSince(monthStart)
        }
    }

    // スクロール位置（＝表示ページの左端）が取り得る範囲。
    // lower: 最初の記録を含むページの先頭（記録がなければ今日のページ）
    // upper: 今日を含むページの先頭
    // いずれも「今日のページ」からページ幅の整数倍だけ遡った位置に揃えることで、
    // ページングの境界が暦の境界（週始まり・日・月初）と一致するようにしている。
    private func scrollPositionBounds(for span: ChartSpan) -> (lower: Date, upper: Date) {
        let calendar = Calendar.current
        let pageStart = Self.todayScrollPosition(for: span)
        let earliest = min(sortedRowsForChart.first?.bucketDate ?? pageStart, pageStart)

        switch span {
        case .sevenDays:
            let days = max(calendar.dateComponents([.day], from: earliest, to: pageStart).day ?? 0, 0)
            let pages = (days + 6) / 7
            let lower = calendar.date(byAdding: .day, value: -7 * pages, to: pageStart) ?? earliest
            return (lower, pageStart)
        case .thirtyDays:
            let days = max(calendar.dateComponents([.day], from: earliest, to: pageStart).day ?? 0, 0)
            let pages = (days + 29) / 30
            let lower = calendar.date(byAdding: .day, value: -30 * pages, to: pageStart) ?? earliest
            return (lower, pageStart)
        case .twelveMonths:
            let months = max(calendar.dateComponents([.month], from: earliest, to: pageStart).month ?? 0, 0)
            let pages = (months + 11) / 12
            let lower = calendar.date(byAdding: .month, value: -12 * pages, to: pageStart) ?? earliest
            return (lower, pageStart)
        }
    }

    // 任意の候補位置を「その日付を含むページの先頭」に揃えたうえで、
    // スクロール可能範囲（最初の記録を含むページ〜今日のページ）内へクランプする。
    // ページ境界の外や記録のない領域へスクロール位置が設定されるのを防ぐ。
    private func clampedPageAlignedScrollPosition(_ candidate: Date, for span: ChartSpan) -> Date {
        let calendar = Calendar.current
        let bounds = scrollPositionBounds(for: span)

        let aligned: Date
        switch span {
        case .sevenDays:
            aligned = calendar.dateInterval(of: .weekOfYear, for: candidate)?.start
                ?? calendar.startOfDay(for: candidate)
        case .thirtyDays:
            let day = calendar.startOfDay(for: candidate)
            let offsetDays = calendar.dateComponents([.day], from: bounds.upper, to: day).day ?? 0
            let pageIndex = Int(floor(Double(offsetDays) / 30.0))
            aligned = calendar.date(byAdding: .day, value: pageIndex * 30, to: bounds.upper) ?? day
        case .twelveMonths:
            let month = calendar.date(from: calendar.dateComponents([.year, .month], from: candidate)) ?? candidate
            let offsetMonths = calendar.dateComponents([.month], from: bounds.upper, to: month).month ?? 0
            let pageIndex = Int(floor(Double(offsetMonths) / 12.0))
            aligned = calendar.date(byAdding: .month, value: pageIndex * 12, to: bounds.upper) ?? month
        }

        return min(max(aligned, bounds.lower), bounds.upper)
    }

    // チャートのX軸ドメイン（スクロール可能な全範囲）。
    // Swift Chartsはプロットされたデータからドメインを推定するため、明示指定しないと
    // 最初の記録より前や最後の記録より後（今日・未来を含む）へスクロールできない。
    // ヘルスケアと同様に、記録の有無に関わらず
    // 「最初の記録を含むページの先頭 〜 今日を含むページの末尾」だけを正確にカバーし、
    // それより先（過去・未来とも）へはスワイプしても跳ね戻るようにする。
    private var chartXDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let bounds = scrollPositionBounds(for: span)

        switch span {
        case .sevenDays:
            let upper = calendar.date(byAdding: .day, value: 7, to: bounds.upper) ?? bounds.upper
            return bounds.lower...upper
        case .thirtyDays:
            let upper = calendar.date(byAdding: .day, value: 30, to: bounds.upper) ?? bounds.upper
            return bounds.lower...upper
        case .twelveMonths:
            let upper = calendar.date(byAdding: .month, value: 12, to: bounds.upper) ?? bounds.upper
            return bounds.lower...upper
        }
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
        let now = Date()
        let (rangeStart, rangeEnd) = alignedVisibleRange()

        // 表示範囲内のすべてのバケット（日または月）を生成し、
        // ロード時に事前集計済みの totalsByBucket から合計を引くだけにする。
        // 週・年表示のページは今日より後（未来）のバケットも含むため、
        // まだ始まっていないバケットは平均の分母から除外する（ヘルスケア準拠）
        var bucketCount = 0
        var totalMinutes = 0.0
        var current = rangeStart
        while current < rangeEnd {
            if current <= now {
                bucketCount += 1
                totalMinutes += totalsByBucket[current] ?? 0.0
            }
            switch span {
            case .sevenDays, .thirtyDays:
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            case .twelveMonths:
                current = calendar.date(byAdding: .month, value: 1, to: current)!
            }
        }

        guard bucketCount > 0 else { return 0 }
        return totalMinutes / Double(bucketCount)
    }

    // 表示範囲の合計学習時間
    var totalStudyTimeInVisibleRange: Double {
        let calendar = Calendar.current
        let (rangeStart, rangeEnd) = alignedVisibleRange()

        var totalMinutes = 0.0
        var current = rangeStart
        while current < rangeEnd {
            totalMinutes += totalsByBucket[current] ?? 0.0
            switch span {
            case .sevenDays, .thirtyDays:
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            case .twelveMonths:
                current = calendar.date(byAdding: .month, value: 1, to: current)!
            }
        }
        return totalMinutes
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
    
    // 「今日」の適切なスクロール位置を計算（今日/今月が右端に来る位置）
    private func getTodayScrollPosition() -> Date {
        Self.todayScrollPosition(for: span)
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
    
    // 現在表示中のページ内で最も学習時間が長かったバケットの合計値をもとに、
    // Y軸上限を再計算する（ヘルスケア準拠: スクロール中は据え置き、静止後に高さへフィットさせる）
    private func recalculateYAxisDomain(animated: Bool) {
        let calendar = Calendar.current
        let (rangeStart, rangeEnd) = alignedVisibleRange()

        var maxValue = 0.0
        var current = rangeStart
        while current < rangeEnd {
            maxValue = max(maxValue, totalsByBucket[current] ?? 0.0)
            switch span {
            case .sevenDays, .thirtyDays:
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            case .twelveMonths:
                current = calendar.date(byAdding: .month, value: 1, to: current)!
            }
        }

        // 最も高いバーの上に少し余白を残しつつ、データがないページでも
        // グラフが極端に潰れないよう最低限の高さを確保する
        let newUpperBound = max(maxValue * 1.2, 30)
        guard abs(newUpperBound - yAxisUpperBound) > 0.5 else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                yAxisUpperBound = newUpperBound
            }
        } else {
            yAxisUpperBound = newUpperBound
        }
    }

    // スクロール中は毎フレーム呼ばれるため、その都度再計算せず一定時間の静止を待ってから実行する
    private func scheduleYAxisRecalc() {
        yAxisRecalcTask?.cancel()
        yAxisRecalcTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            recalculateYAxisDomain(animated: true)
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
                            Text(span == .twelveMonths ? "月平均" : "平均")
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
                if isLoading && rows.isEmpty {
                    // ローディング中（初回ロード時のみ。スパン切替時は直前のデータを表示し続ける）
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
        let selectedBucketDate = selectedDate.map { normalizedBucketDate(for: $0) }
        Chart(sortedRowsForChart) { row in
            BarMark(
                x: .value("Period", row.bucketDate, unit: span.xUnit),
                y: .value("Minutes", row.durationMinutes)
            )
            .foregroundStyle(row.subjectColor)
            .opacity(selectedBucketDate == nil || row.bucketDate == selectedBucketDate! ? 1.0 : 0.25)
        }
        .chartScrollableAxes(.horizontal)
        // 記録の前後（今日を含む現在のページまで）も含む明示的なドメインを指定し、
        // データが存在しない期間へも確実にスクロールできるようにする
        .chartXScale(domain: chartXDomain)
        .chartScrollTargetBehavior(HealthStylePagingBehavior(span: span))
        .chartXVisibleDomain(length: currentVisibleLength)
        .chartScrollPosition(x: $scrollPos)
        // Y軸はスクロール中固定し、静止後（scheduleYAxisRecalc経由）に表示ページへフィットさせる
        .chartYScale(domain: 0...yAxisUpperBound)
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
        .chartXSelection(value: $selectedDate)
        .chartOverlay { proxy in
            GeometryReader { geo in
                chartSelectionOverlay(proxy: proxy, geometry: geo)
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            if let newValue {
                let bucket = normalizedBucketDate(for: newValue)
                if lastHapticBucketDate != bucket {
                    HapticFeedback.light()
                    lastHapticBucketDate = bucket
                }
            } else {
                lastHapticBucketDate = nil
            }
        }
        .onChange(of: scrollPos) { _, _ in
            scheduleYAxisRecalc()
        }
    }
    
    // MARK: - データ読み込み（全データ一括読み込み）
    private func loadData() async {
        await MainActor.run {
            // 初回ロード時のみスピナーを表示する。スパン切替時は直前のデータを表示し続け、
            // 裏で読み込みが完了次第、新しいスパンのデータに差し替える（ヘルスケア準拠のUX）。
            isLoading = true

            // スパンが切り替わった場合、切替前に見ていた日付付近を新しいスパンでも維持する
            // （例: 週→月なら、見ていた週を含む30日間が表示される）
            if hasLoadedOnce && lastLoadedSpan != span {
                scrollPos = convertScrollPosition(scrollPos, from: lastLoadedSpan, to: span)
            }
            lastLoadedSpan = span
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
                let isFirstLoad = !hasLoadedOnce
                applyLoadedRows(newRows)
                isLoading = false
                if isFirstLoad {
                    // 初回ロード時のみ「今日が右端」の位置へ調整する。
                    // スパン切替時はすでにこの関数の冒頭で位置を維持済みのため上書きしない。
                    scrollPos = Self.todayScrollPosition(for: span)
                    hasLoadedOnce = true
                } else {
                    // データの読み込みでスクロール可能範囲（最初の記録の位置）が確定・変化した後も、
                    // 現在位置がページ境界と可動範囲の中に収まるよう矯正する
                    scrollPos = clampedPageAlignedScrollPosition(scrollPos, for: span)
                }
                // データ読み込み直後は「静止後」の一種として即座にY軸を合わせる（待たずに反映）。
                // 初回表示時はアニメーションさせず、切替・再読み込み時のみ滑らかに遷移させる。
                yAxisRecalcTask?.cancel()
                recalculateYAxisDomain(animated: !isFirstLoad)
            }
        } catch {
            await MainActor.run {
                print("Chart load error:", error)
                if !hasLoadedOnce {
                    rows = []
                    sortedRowsForChart = []
                    totalsByBucket = [:]
                    rowsByBucket = [:]
                }
                isLoading = false
            }
        }
    }

    // 読み込んだ行を保持しつつ、スクロール中に毎フレーム再計算しなくて済むよう
    // ソート済み配列とバケット別の集計を一度だけ構築する
    @MainActor
    private func applyLoadedRows(_ newRows: [ChartRow]) {
        rows = newRows

        sortedRowsForChart = newRows.sorted { lhs, rhs in
            if lhs.bucketDate != rhs.bucketDate {
                return lhs.bucketDate < rhs.bucketDate
            }
            if lhs.durationMinutes != rhs.durationMinutes {
                return lhs.durationMinutes > rhs.durationMinutes
            }
            if lhs.subjectName != rhs.subjectName {
                return lhs.subjectName < rhs.subjectName
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        rowsByBucket = Dictionary(grouping: newRows, by: { $0.bucketDate })
        totalsByBucket = rowsByBucket.mapValues { bucketRows in
            bucketRows.reduce(0.0) { $0 + $1.durationMinutes }
        }
    }

    // スパン切替時、切替前に見ていた表示範囲の代表日（中心付近）を含むページへ変換する
    // （例: 週→月なら、見ていた週を含む30日ページを表示）。
    // 変換結果は新しいスパンのページ境界に揃え、スクロール可能範囲内へクランプする。
    private func convertScrollPosition(_ position: Date, from oldSpan: ChartSpan, to newSpan: ChartSpan) -> Date {
        guard oldSpan != newSpan else { return position }

        let calendar = Calendar.current

        // 直前に見ていた範囲の中心付近の日付を基準にする
        let oldVisibleLength: TimeInterval
        switch oldSpan {
        case .sevenDays, .thirtyDays:
            oldVisibleLength = oldSpan.visibleLength
        case .twelveMonths:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: position)) ?? position
            let monthEnd = calendar.date(byAdding: .month, value: 12, to: monthStart) ?? monthStart
            oldVisibleLength = monthEnd.timeIntervalSince(monthStart)
        }
        let anchorDate = position.addingTimeInterval(oldVisibleLength / 2)

        return clampedPageAlignedScrollPosition(anchorDate, for: newSpan)
    }

    // MARK: - Selection Helpers & Overlay
    private func normalizedBucketDate(for date: Date) -> Date {
        let calendar = Calendar.current
        switch span {
        case .sevenDays, .thirtyDays:
            return calendar.startOfDay(for: date)
        case .twelveMonths:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        }
    }
    
    // DateFormatterの生成コストを避けるため使い回す（選択中はドラッグ移動のたびに呼ばれる）
    private static let dayTooltipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter
    }()
    private static let monthTooltipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private func tooltipTitle(for bucketDate: Date) -> String {
        switch span {
        case .sevenDays, .thirtyDays:
            return Self.dayTooltipFormatter.string(from: bucketDate)
        case .twelveMonths:
            return Self.monthTooltipFormatter.string(from: bucketDate)
        }
    }
    
    @ViewBuilder
    private func chartSelectionOverlay(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        if let selectedDate = selectedDate {
            let bucketDate = normalizedBucketDate(for: selectedDate)
            if let plotAnchor = proxy.plotFrame,
               let positionX = proxy.position(forX: bucketDate) {
                let plotRect = geometry[plotAnchor]
                let lineX = positionX + plotRect.origin.x
                let tooltipWidth: CGFloat = 180
                let placeRight = lineX + 8 + tooltipWidth < geometry.size.width
                let tooltipLeftX = max(8, min(geometry.size.width - tooltipWidth - 8, placeRight ? lineX + 8 : lineX - tooltipWidth - 8))
                let tooltipTopY = plotRect.origin.y + 8

                let bucketRows = rowsByBucket[bucketDate] ?? []
                let totalMinutes = totalsByBucket[bucketDate] ?? 0.0
                let sortedRows = bucketRows.sorted { $0.durationMinutes > $1.durationMinutes }

                ZStack(alignment: .topLeading) {

                    // Tooltip
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tooltipTitle(for: bucketDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("合計")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatMinutesToHourMinute(totalMinutes))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        if !sortedRows.isEmpty {
                            Divider().opacity(0.6)
                            ForEach(Array(sortedRows.prefix(5).enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(item.subjectColor)
                                        .frame(width: 6, height: 6)
                                    Text(item.subjectName)
                                        .font(.caption2)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(formatMinutesToHourMinute(item.durationMinutes))
                                        .font(.caption2)
                                }
                            }
                            if sortedRows.count > 5 {
                                Text("他 \(sortedRows.count - 5) 件")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("記録なし")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                    .frame(width: tooltipWidth)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    .position(x: tooltipLeftX + tooltipWidth / 2, y: tooltipTopY)
                }
            } else {
                Color.clear
            }
        } else {
            Color.clear
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

// MARK: - スクロール吸着挙動（ヘルスケア準拠のページング）
// スパンごとに最適な吸着挙動へ委譲する。単一の型にまとめることで、
// スパン切替時にチャートのビュー階層（スクロール状態）を作り直さずに済む。
private struct HealthStylePagingBehavior: ChartScrollTargetBehavior {
    let span: ChartSpan

    nonisolated func updateTarget(_ target: inout ScrollTarget, context: ChartScrollTargetBehaviorContext) {
        switch span {
        case .sevenDays, .thirtyDays:
            // 週・月表示: 標準のページング挙動（フリック速度に応じて複数ページ動くこともある）。
            //
            // ジェスチャー開始位置を基準に「1ページを超える移動量だけ弱める」後処理を試みたが、
            // システムが計算したスクロールの減速アニメーションと、後から書き換えた目標位置が
            // 噛み合わずアニメーションがガクつく結果になったため撤回し、標準の挙動に戻している。
            // スナップ先の感度調整とアニメーションの滑らかさを両立させるには、実機での
            // 試行錯誤を伴う調整が必要と判断した。
            PagingScrollTargetBehavior().updateTarget(&target, context: context)
        case .twelveMonths:
            // 年表示: 月ごとに日数が異なるため固定長ページングでは月境界からずれてしまう。
            // 月初への吸着＋ページ単位のメジャー吸着を組み合わせ、
            // 暦に正しく揃えつつ12ヶ月単位のページめくり感を出す。
            ValueAlignedChartScrollTargetBehavior(
                matching: DateComponents(day: 1),
                majorAlignment: .page
            ).updateTarget(&target, context: context)
        }

        // 吸着先をスクロール可能範囲（chartXDomainが定める全ページ）内へクランプする。
        // 最初の記録より前・今日のページより先へは吸着させず、端でのスワイプは跳ね戻る。
        let maxOriginX = max(context.contentSize.width - context.containerSize.width, 0)
        target.rect.origin.x = min(max(target.rect.origin.x, 0), maxOriginX)
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
        case .twelveMonths:
            // 年表示の実際の可視域は月初からの12ヶ月分（うるう年等で日数が変動する）を
            // 動的に計算する（StudyTimeCharts.currentVisibleLength を参照）。
            // ここでは Calendar 計算に失敗した場合のフォールバック用の近似値（365日）を返す。
            return day * 365
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
    
    @AxisContentBuilder
    var axisMarks: some AxisContent {
        switch self {
        case .sevenDays:
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    // 週の区切り（システム設定の週始まりの曜日）を強調表示する
                    let weekday = Calendar.current.component(.weekday, from: date)
                    let isWeekStart = (weekday == Calendar.current.firstWeekday)

                    AxisGridLine(stroke: StrokeStyle(
                        lineWidth: isWeekStart ? 1.0 : 0.5,
                        dash: isWeekStart ? [] : [2, 2]
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
                if value.as(Date.self) != nil {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1.0))
                    AxisTick()
                }
            }
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    // 週の区切り（システム設定の週始まりの曜日）ごとに日付ラベルを表示する
                    let weekday = Calendar.current.component(.weekday, from: date)
                    if weekday == Calendar.current.firstWeekday {
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
    
    // DateFormatterの生成はロケール初期化を伴い重いため、軸ラベル用に使い回す
    // （スクロール中は軸ラベルが毎フレーム再評価されるため、ここでの生成コストが
    // スクロールのもたつきに直結する）。
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter
    }()

    private func weekdayString(from date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
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
    StudyTimeCharts()
        .environment(DIContainer.shared)
}

#Preview("年表示") {
    StudyTimeCharts()
        .environment(DIContainer.shared)
}
