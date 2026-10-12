//
// StudyTimeCharts.swift
// Studies
//
// 7-day / 30-day / 12-month 学習時間チャート
//

import SwiftUI
import Charts
import os

struct StudyTimeCharts: View {
    @Environment(DIContainer.self) private var di
    @State private var span: ChartSpan = .sevenDays
    @State private var rows: [ChartRow] = []
    @State private var scrollPos: Date
    @State private var isLoading = false
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

    // Y軸の表示上限と目盛り間隔（表示範囲が静止した後に再計算する）
    @State private var yAxisUpperBound: Double = 60
    @State private var yAxisStep: Double = 15

    // 平均・合計・期間表示・Y軸の基準にする「静止した」スクロール位置。
    // ヘルスケアと同様、スクロール中は毎フレーム追従させず、動きが止まってから更新する
    @State private var settledScrollPos: Date
    @State private var settleTask: Task<Void, Never>?

    @State private var showDatePickerSheet = false
    @State private var tempDateSelection = Date()

    init() {
        let initial = Self.todayScrollPosition(for: .sevenDays)
        _scrollPos = State(initialValue: initial)
        _settledScrollPos = State(initialValue: initial)
    }

    // 「今日」で終わる期間の先頭位置を計算（インスタンス生成前や初期値計算にも使えるようstatic化）
    // ヘルスケア準拠: 週は今日を含む直近7日間、月は直近31日間、年は今月が右端に来る12ヶ月
    private static func todayScrollPosition(for span: ChartSpan) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch span {
        case .sevenDays, .thirtyDays:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(byAdding: .day, value: -span.visibleDays, to: tomorrow) ?? now
        case .twelveMonths:
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return calendar.date(byAdding: .month, value: -11, to: currentMonthStart) ?? currentMonthStart
        }
    }

    // 年表示は月ごとに日数が異なる（うるう年など）ため、スクロール位置（月初）を基準に
    // 実際の12ヶ月分の長さを都度計算する。週・月表示は固定長（7日／31日）。
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

    // スクロール位置（＝表示範囲の左端）が取り得る範囲。
    // lower: 最初の記録の日（年表示はその月の月初）。記録がなければ今日の位置
    // upper: 今日で終わる期間の先頭
    private func scrollPositionBounds(for span: ChartSpan) -> (lower: Date, upper: Date) {
        let calendar = Calendar.current
        let upper = Self.todayScrollPosition(for: span)
        let earliest = min(sortedRowsForChart.first?.bucketDate ?? upper, upper)

        switch span {
        case .sevenDays, .thirtyDays:
            return (calendar.startOfDay(for: earliest), upper)
        case .twelveMonths:
            let lower = calendar.date(from: calendar.dateComponents([.year, .month], from: earliest)) ?? earliest
            return (min(lower, upper), upper)
        }
    }

    // 指定日が右端（最終日・最終月）に来る表示範囲の先頭位置を、
    // スクロール可能範囲（最初の記録〜今日で終わる期間）内へクランプして返す
    private func scrollPosition(endingAt date: Date, for span: ChartSpan) -> Date {
        let calendar = Calendar.current
        let bounds = scrollPositionBounds(for: span)

        let start: Date
        switch span {
        case .sevenDays, .thirtyDays:
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
            start = calendar.date(byAdding: .day, value: -span.visibleDays, to: nextDay) ?? date
        case .twelveMonths:
            let month = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            start = calendar.date(byAdding: .month, value: -11, to: month) ?? month
        }

        return min(max(start, bounds.lower), bounds.upper)
    }

    // チャートのX軸ドメイン（スクロール可能な全範囲）。
    // Swift Chartsはプロットされたデータからドメインを推定するため、明示指定しないと
    // 最初の記録より前や最後の記録より後（今日・未来を含む）へスクロールできない。
    // ヘルスケアと同様に、記録の有無に関わらず「最初の記録 〜 今日」だけを正確にカバーし、
    // それより先（過去・未来とも）へはスワイプしても跳ね戻るようにする。
    private var chartXDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let bounds = scrollPositionBounds(for: span)

        switch span {
        case .sevenDays, .thirtyDays:
            let upper = calendar.date(byAdding: .day, value: span.visibleDays, to: bounds.upper) ?? bounds.upper
            return bounds.lower...upper
        case .twelveMonths:
            let upper = calendar.date(byAdding: .month, value: 12, to: bounds.upper) ?? bounds.upper
            return bounds.lower...upper
        }
    }


    var dateRangeString: String {
        let calendar = Calendar.current
        let (rangeStart, rangeEnd) = alignedVisibleRange()
        // 年月日を手で組み立てると String(localized:) の数値書式で年に桁区切り（2,026年）が付くため、
        // 日付範囲の書式化はロケールに合わせて標準フォーマッタに任せる
        switch span {
        case .sevenDays, .thirtyDays:
            let endDisplay = calendar.date(byAdding: .day, value: -1, to: rangeEnd) ?? rangeEnd
            return (rangeStart..<endDisplay).formatted(.interval.year().month(.abbreviated).day())

        case .twelveMonths:
            let endDisplay = calendar.date(byAdding: .month, value: -1, to: rangeEnd) ?? rangeEnd
            // 1月〜12月のちょうど1年分は年だけを表示する
            if calendar.component(.year, from: rangeStart) == calendar.component(.year, from: endDisplay) {
                return rangeStart.formatted(.dateTime.year())
            }
            return (rangeStart..<endDisplay).formatted(.interval.year().month(.abbreviated))
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
    
    // 今日で終わる期間のスクロール位置。
    // タブを開く・開き直すたびに body 末尾の onAppear から呼ばれ、常に最近の期間へ戻す。
    private func getTodayScrollPosition() -> Date {
        Self.todayScrollPosition(for: span)
    }
    
    // 静止したスクロール位置から表示範囲の基準日を求める。
    // 吸着位置の座標変換（オフセット⇔日付）にはわずかな浮動小数誤差が乗り、
    // 日境界・月初のごく直前（例: 前日の23:59:59）に静止することがある。
    // 生の値から日境界や月初を取ると1日（1ヶ月）前として集計されてしまうため、
    // 半日分ずらして日単位に丸めることで誤差を吸収する。
    private func errorToleratedScrollReference() -> Date {
        Calendar.current.startOfDay(for: settledScrollPos.addingTimeInterval(43_200))
    }

    // 表示範囲を日・月境界に揃えて取得（終了は排他的）
    private func alignedVisibleRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let reference = errorToleratedScrollReference()
        switch span {
        case .sevenDays, .thirtyDays:
            let end = calendar.date(byAdding: .day, value: span.visibleDays, to: reference) ?? reference
            return (reference, end)
        case .twelveMonths:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: reference))!
            let end = calendar.date(byAdding: .month, value: 12, to: start) ?? start
            return (start, end)
        }
    }
    
    // 表示範囲内で最も学習時間が長かったバケットの合計値をもとに、Y軸の上限と目盛りを再計算する
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

        let (newUpperBound, newStep) = Self.niceYAxis(forMaxMinutes: maxValue)
        guard newUpperBound != yAxisUpperBound || newStep != yAxisStep else { return }

        if animated {
            withAnimation(.smooth(duration: 0.35)) {
                yAxisUpperBound = newUpperBound
                yAxisStep = newStep
            }
        } else {
            yAxisUpperBound = newUpperBound
            yAxisStep = newStep
        }
    }

    // 上限を「区切りのよい刻み × 4以下」に丸める。
    // 最大値に比例させると少しスクロールしただけで軸が伸び縮みし、目盛りも半端な値になるため、
    // ヘルスケアと同様に刻みが変わる時だけ軸が動くようにする。
    // データがないページでもグラフが潰れないよう、最低でも30分の高さを確保する。
    private static func niceYAxis(forMaxMinutes maxMinutes: Double) -> (upperBound: Double, step: Double) {
        let target = max(maxMinutes * 1.1, 30)
        let steps: [Double] = [15, 30, 60, 90, 120, 180, 240, 360, 480, 600, 720, 1200, 1800, 2400, 3600, 6000, 12000]
        let step = steps.first { (target / $0).rounded(.up) <= 4 } ?? (target / 4).rounded(.up)
        return ((target / step).rounded(.up) * step, step)
    }

    // スクロール中は毎フレーム呼ばれるため、一定時間動きが止まるのを待ってから
    // 平均・合計・期間表示とY軸をまとめて更新する
    private func scheduleSettle() {
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            settle(animated: true)
        }
    }

    private func settle(animated: Bool) {
        settleTask?.cancel()
        settledScrollPos = scrollPos
        recalculateYAxisDomain(animated: animated)
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("表示期間", selection: $span) {
                    Text("週").tag(ChartSpan.sevenDays)
                    // 曜日の「月(Mon)」と表示文字列が衝突するため、キーを明示的に分離する
                    Text(String(localized: "chartSpan.month", defaultValue: "月")).tag(ChartSpan.thirtyDays)
                    Text("年").tag(ChartSpan.twelveMonths)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .accessibilityLabel("表示期間")
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(span == .twelveMonths ? "月平均" : "平均")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            formatDurationWithStyle(averageStudyTimeInVisibleRange)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("合計")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            formatDurationWithStyle(totalStudyTimeInVisibleRange)
                        }
                    }

                    // 「今日」ボタンは廃止し、代わりにタブを開く（開き直す）たびに
                    // 必ず最近のページへ自動的に戻すようにしている（body末尾のonAppearを参照）。
                    HStack(spacing: 8) {
                        Text(dateRangeString)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button {
                            tempDateSelection = alignedVisibleRange().start
                            showDatePickerSheet = true
                        } label: {
                            Image(systemName: "calendar")
                        }
                        .buttonStyle(.plain)
                        .disabled(rows.isEmpty)
                        .accessibilityLabel("表示期間を変更")

                        Spacer()
                    }
                }
                .padding(.horizontal)
            }

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
                    createChart()
                        .frame(height: 240)
                        .padding(.horizontal)
                }
            }
        }
        .task(id: span) { await loadData() }
        .onAppear {
            // 統計タブを開く・開き直すたびに、常に「週」表示・最近のページ（今日を含む
            // ページ）へ戻す。「今日」ボタンを廃止した代わりに、離れていた表示状態から
            // 復帰する手段をここに一本化している。
            // lastLoadedSpanも一致させておくことで、.task(id: span)経由のloadData内にある
            // 「スパン切替時に直前の表示位置を変換して引き継ぐ」ロジックが働かないようにし、
            // 意図せず中途半端な位置に変換されるのを防ぐ。アニメーションはさせず即座に切り替える。
            span = .sevenDays
            lastLoadedSpan = .sevenDays
            scrollPos = getTodayScrollPosition()
            settle(animated: false)
        }
        .sheet(isPresented: $showDatePickerSheet) {
            datePickerSheet
        }
    }

    private var datePickerSheet: some View {
        // 選択できるのはスクロール可能な範囲（最初の記録〜今日）のみ
        let pickerRange = scrollPositionBounds(for: span).lower...Date()

        return NavigationStack {
            DatePicker(
                "",
                selection: $tempDateSelection,
                in: pickerRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .onChange(of: tempDateSelection) { _, newValue in
                // 選んだ日が右端に来る期間を表示する
                scrollPos = scrollPosition(endingAt: newValue, for: span)
                settle(animated: true)
                showDatePickerSheet = false
            }
            .navigationTitle("表示する日付を選択")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
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
            .opacity(selectedBucketDate == nil || row.bucketDate == selectedBucketDate ? 1.0 : 0.25)
        }
        .chartScrollableAxes(.horizontal)
        // 記録の前後（今日まで）も含む明示的なドメインを指定し、
        // データが存在しない期間へも確実にスクロールできるようにする
        .chartXScale(domain: chartXDomain)
        .chartScrollTargetBehavior(
            HealthStyleScrollBehavior(span: span, domain: chartXDomain)
        )
        .chartXVisibleDomain(length: currentVisibleLength)
        .chartScrollPosition(x: $scrollPos)
        // Y軸はスクロール中固定し、静止後（scheduleSettle経由）に表示範囲へフィットさせる
        .chartYScale(domain: 0...yAxisUpperBound)
        // スクロール中は固定しているY軸の上限を超えるバーが上へ突き抜けず、
        // プロット領域の上端で切れて見えるようにする。
        // Rectangle()そのままでクリップすると、プロット領域内に描かれる横軸ラベル
        // （スクロールに追従する曜日・日付ラベル）まで切れてしまうため、
        // 上端だけで切り、下方向には余裕を持たせた専用形状を使う。
        .chartPlotStyle { plotArea in
            plotArea.clipShape(PlotTopEdgeClipShape())
        }
        .chartXAxis {
            span.axisMarks
        }
        .chartYAxis {
            AxisMarks(values: Array(stride(from: 0, through: yAxisUpperBound, by: yAxisStep))) { value in
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
            scheduleSettle()
        }
        .accessibilityLabel("学習時間グラフ")
        .accessibilityValue("\(dateRangeString)、合計\(formatMinutesToHourMinute(totalStudyTimeInVisibleRange))")
    }

    // MARK: - データ読み込み（全データ一括読み込み）
    private func loadData() async {
        await MainActor.run {
            // 初回ロード時のみスピナーを表示する。スパン切替時は直前のデータを表示し続け、
            // 裏で読み込みが完了次第、新しいスパンのデータに差し替える（ヘルスケア準拠のUX）。
            isLoading = true

            // スパンが切り替わった場合、切替前に見ていた期間の最終日を新しいスパンでも右端に維持する
            // （例: 週→月なら、見ていた週の最終日で終わる31日間が表示される）
            if hasLoadedOnce && lastLoadedSpan != span {
                scrollPos = convertScrollPosition(settledScrollPos, from: lastLoadedSpan, to: span)
                settledScrollPos = scrollPos
            }
            lastLoadedSpan = span
        }

        do {
            let manager = StudyChartDataManager(useCase: di.studyRecordUseCase)
            let subjects = try await di.subjectUseCase.getAllSubjects()

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
                    // 現在位置が日・月境界と可動範囲の中に収まるよう矯正する
                    scrollPos = clampedScrollPosition(scrollPos, for: span)
                }
                // データ読み込み直後は「静止後」の一種として待たずに反映する。
                // 初回表示時はアニメーションさせず、切替・再読み込み時のみ滑らかに遷移させる。
                settle(animated: !isFirstLoad)
            }
        } catch {
            await MainActor.run {
                Logger.ui.error("Chart load error: \(error)")
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

    // スパン切替時、切替前に見ていた表示範囲の最終日が新しいスパンでも右端に来る位置へ変換する
    private func convertScrollPosition(_ position: Date, from oldSpan: ChartSpan, to newSpan: ChartSpan) -> Date {
        guard oldSpan != newSpan else { return position }

        let calendar = Calendar.current
        let reference = calendar.startOfDay(for: position.addingTimeInterval(43_200))
        let oldEnd: Date
        switch oldSpan {
        case .sevenDays, .thirtyDays:
            oldEnd = calendar.date(byAdding: .day, value: oldSpan.visibleDays, to: reference) ?? reference
        case .twelveMonths:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: reference)) ?? reference
            oldEnd = calendar.date(byAdding: .month, value: 12, to: monthStart) ?? monthStart
        }
        // oldEnd は排他的な終端なので、その直前（最終日・最終月）を右端にする
        return scrollPosition(endingAt: oldEnd.addingTimeInterval(-1), for: newSpan)
    }

    // 任意の位置を日境界（年表示は月初）に揃え、スクロール可能範囲内へクランプする
    private func clampedScrollPosition(_ position: Date, for span: ChartSpan) -> Date {
        let calendar = Calendar.current
        let bounds = scrollPositionBounds(for: span)
        let day = calendar.startOfDay(for: position.addingTimeInterval(43_200))
        let aligned: Date
        switch span {
        case .sevenDays, .thirtyDays:
            aligned = day
        case .twelveMonths:
            aligned = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? day
        }
        return min(max(aligned, bounds.lower), bounds.upper)
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
        formatter.setLocalizedDateFormatFromTemplate("yMMMdE")
        return formatter
    }()
    private static let monthTooltipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
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
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                    .position(x: tooltipLeftX + tooltipWidth / 2, y: tooltipTopY)
                }
            } else {
                Color.clear
            }
        } else {
            Color.clear
        }
    }
    
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
                // チャートの大数字の単位サフィックスは、Weekday(月曜日略称「月」)等との
                // 表示文字列の衝突を避けるためキーを明示的に分離する
                Text(String(localized: "chart.unit.hours", defaultValue: "時間"))
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)

                if mins > 0 {
                    Text("\(mins)")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.primary)
                        .fontDesign(.rounded)
                    Text(String(localized: "chart.unit.minutes", defaultValue: "分"))
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                }
            } else {
                Text("\(mins)")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.primary)
                    .fontDesign(.rounded)
                Text(String(localized: "chart.unit.minutes", defaultValue: "分"))
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - スクロール吸着挙動（ヘルスケア準拠）

// ヘルスケアと同様、ゆっくり動かして離すと週・月表示は最寄りの日境界、年表示は月初に止め、
// 勢いよく払うと週表示は払った向きの次の週始まり（端末設定の曜日）へ、
// 月表示はドラッグ開始位置から1ページ（31日）ちょうど進める。
// スパンごとに別の型を渡すとスパン切替時にチャートのビュー階層（スクロール状態）が
// 作り直されるため、単一の型の中で振り分ける。
private struct HealthStyleScrollBehavior: ChartScrollTargetBehavior {
    let span: ChartSpan
    // スクロールオフセット⇔日付の変換に使う（データ変化時以外は不変）
    let domain: ClosedRange<Date>

    nonisolated func updateTarget(_ target: inout ScrollTarget, context: ChartScrollTargetBehaviorContext) {
        switch span {
        case .sevenDays:
            snapToDay(&target, context: context, visibleDays: 7, flicksToWeekStart: true)
        case .thirtyDays:
            snapToDay(&target, context: context, visibleDays: 31, flicksToWeekStart: false)
        case .twelveMonths:
            ValueAlignedChartScrollTargetBehavior(
                matching: DateComponents(day: 1),
                majorAlignment: .page
            ).updateTarget(&target, context: context)
        }

        // 吸着先をスクロール可能範囲（chartXDomain）内へクランプし、端でのスワイプは跳ね戻らせる
        let maxOriginX = max(context.contentSize.width - context.containerSize.width, 0)
        target.rect.origin.x = min(max(target.rect.origin.x, 0), maxOriginX)
    }

    // 標準の値吸着（matching: hour 0）では日境界に止まらないことがあったため、
    // 停止位置を日付へ変換して自前で日境界に揃える。
    // ChartSpan.visibleDays はMainActor分離のため、nonisolatedなこの文脈では引数で受け取る。
    nonisolated private func snapToDay(
        _ target: inout ScrollTarget,
        context: ChartScrollTargetBehaviorContext,
        visibleDays: Int,
        flicksToWeekStart: Bool
    ) {
        let contentWidth = Double(context.contentSize.width)
        let containerWidth = Double(context.containerSize.width)
        let domainSeconds = domain.upperBound.timeIntervalSince(domain.lowerBound)
        let visibleSeconds = 86_400.0 * Double(visibleDays)

        // 「コンテンツ全体の幅＝ドメイン全体」「コンテナ幅＝可視域」という縮尺の前提が
        // 成り立っているか自己検証する（プロット領域のインセット等でずれている場合に
        // 誤った位置へ吸着させないため）。成り立たない場合は自然な停止位置のままにする。
        let secondsPerPoint = domainSeconds / max(contentWidth, 1)
        let expectedContainerWidth = visibleSeconds / secondsPerPoint
        guard contentWidth > 0, containerWidth > 0, domainSeconds > 0,
              abs(expectedContainerWidth - containerWidth) <= containerWidth * 0.05 else {
            return
        }

        func date(atOffset x: CGFloat) -> Date {
            domain.lowerBound.addingTimeInterval(Double(x) * secondsPerPoint)
        }
        func nearestDay(_ date: Date) -> Date {
            Calendar.current.startOfDay(for: date.addingTimeInterval(43_200))
        }

        let velocityX = Double(context.velocity.dx)

        let snapped: Date
        if abs(velocityX) >= Self.flickVelocityThreshold {
            let calendar = Calendar.current
            let startDay = nearestDay(date(atOffset: context.originalTarget.rect.origin.x))
            let forward = velocityX > 0
            if flicksToWeekStart {
                // 払った向きにある次の週始まりへ進める（週始まりの曜日は Calendar.current.firstWeekday に従う）。
                // 今日で終わる最新ページより先は updateTarget のクランプで最新ページに揃う
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: startDay)?.start ?? startDay
                if forward {
                    snapped = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? startDay
                } else {
                    snapped = weekStart < startDay
                        ? weekStart
                        : calendar.date(byAdding: .day, value: -7, to: weekStart) ?? startDay
                }
            } else {
                // 払った向きへ、ドラッグ開始時の表示位置から1ページちょうど進める
                snapped = calendar.date(byAdding: .day, value: forward ? visibleDays : -visibleDays, to: startDay) ?? startDay
            }
        } else {
            snapped = nearestDay(date(atOffset: target.rect.origin.x))
        }
        target.rect.origin.x = CGFloat(snapped.timeIntervalSince(domain.lowerBound) / secondsPerPoint)
    }

    // これ以上の速さで指を離したら「払った」とみなしてページ単位で動かす。
    // シミュレータでの実測では、ゆっくり動かして離すと0、素早く払うと0.5〜0.7程度だった
    nonisolated private static let flickVelocityThreshold = 0.3
}

// プロット領域の「上端」だけでクリップするための形状。
// 上端はプロット領域の境界ぴったりに保ち（Y軸上限を超えたバーの突き出しを防ぐ）、
// 下方向へは余裕を持たせて、プロット領域内に描画される横軸ラベル
// （曜日・日付）が切れないようにする。左右はスクロールビュー側でマスクされるため
// 変更しない。
private struct PlotTopEdgeClipShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + 60))
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
    
    // ヘルスケア準拠: 週は直近7日間、月は直近31日間（例: 9/12〜10/12）を表示する。
    // 年表示の実際の可視域は月初からの12ヶ月分（うるう年等で日数が変動する）を
    // 動的に計算する（StudyTimeCharts.currentVisibleLength を参照）。
    // ここでの365日は Calendar 計算に失敗した場合のフォールバック用の近似値。
    var visibleDays: Int {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 31
        case .twelveMonths: return 365
        }
    }

    var visibleLength: TimeInterval {
        86_400.0 * Double(visibleDays)
    }
    
    func fullDataRange() -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .sevenDays, .thirtyDays:
            let start = calendar.date(byAdding: .year, value: -5, to: calendar.startOfDay(for: now))!
            return (start, now)

        case .twelveMonths:
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
        formatter.dateFormat = "E"
        return formatter
    }()

    private func weekdayString(from date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
    }
    
    private func monthString(from date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        return String(localized: "\(month)月")
    }

    private func dayOnlyString(from date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return String(localized: "\(day)日")
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
