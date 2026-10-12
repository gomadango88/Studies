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

    // Y軸の表示上限（現在の表示ページに合わせて静止後に再計算する）
    @State private var yAxisUpperBound: Double = 60
    // Y軸再計算のデバウンス用タスク（スクロール中は毎フレーム走らせず、静止を待って1回だけ実行する）
    @State private var yAxisRecalcTask: Task<Void, Never>?

    // 月表示で直前に静止していた月初位置（スワイプの進行方向判定の基準）。
    // 参照型なので、値が更新されても chartScrollTargetBehavior のモディファイア値は
    // 変化せず、減速アニメーション中の再ターゲティングによるガクつきを起こさない。
    @State private var monthScrollAnchor = ChartScrollAnchor(StudyTimeCharts.todayScrollPosition(for: .thirtyDays))

    init() {
        _scrollPos = State(initialValue: Self.todayScrollPosition(for: .sevenDays))
    }

    // 「今日」を含むページの先頭位置を計算（インスタンス生成前や初期値計算にも使えるようstatic化）
    // 週表示は今週の先頭、月表示は今月の月初、年表示は今月が右端に来る位置を返す
    private static func todayScrollPosition(for span: ChartSpan) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch span {
        case .sevenDays:
            // ヘルスケア準拠: 今日を含む「今週」の先頭を表示する
            // （dateInterval(of: .weekOfYear) はシステム設定の週始まりの曜日 Calendar.firstWeekday に従う）
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        case .thirtyDays:
            // 暦の1ヶ月＝1ページ。今日を含む「今月」の月初を表示する
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now))
                ?? calendar.startOfDay(for: now)
        case .twelveMonths:
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return calendar.date(byAdding: .month, value: -11, to: currentMonthStart) ?? currentMonthStart
        }
    }

    // 年表示は月ごとに日数が異なる（うるう年など）ため、スクロール位置（月初）を基準に
    // 実際の12ヶ月分の長さを都度計算する。
    // 週・月表示は固定長（7日／31日）。特に月表示は、可視域を月の長さに合わせて動的に
    // 変えるとスクロール中のジオメトリ再構築で吸着位置やY軸が不安定になったため、
    // 31日固定とし、短い月ではみ出した翌月分は薄色表示で「集計対象外」を示す方式にしている。
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
            // ページ＝暦の1ヶ月なので、最初の記録を含む月の月初がそのまま下限になる
            let lower = calendar.date(from: calendar.dateComponents([.year, .month], from: earliest)) ?? earliest
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
            // 候補日を含む月の月初に揃える
            aligned = calendar.date(from: calendar.dateComponents([.year, .month], from: candidate)) ?? candidate
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
            // 可視域が31日固定のため、最終ページ（今月）の左端が月初に揃うよう
            // 上限は「今月の月初＋31日」とする
            let upper = calendar.date(byAdding: .day, value: 31, to: bounds.upper) ?? bounds.upper
            return bounds.lower...upper
        case .twelveMonths:
            let upper = calendar.date(byAdding: .month, value: 12, to: bounds.upper) ?? bounds.upper
            return bounds.lower...upper
        }
    }


    var dateRangeString: String {
        let calendar = Calendar.current
        let (rangeStart, rangeEnd) = alignedVisibleRange()
        switch span {
        case .thirtyDays:
            // 暦の1ヶ月をそのまま表示しているため「2026年7月」のようにシンプルに表示する
            let year = calendar.component(.year, from: rangeStart)
            let month = calendar.component(.month, from: rangeStart)
            return String(localized: "\(year)年\(month)月")

        case .sevenDays:
            let endDisplay = calendar.date(byAdding: .day, value: -1, to: rangeEnd) ?? rangeEnd
            let startYear = calendar.component(.year, from: rangeStart)
            let startMonth = calendar.component(.month, from: rangeStart)
            let startDay = calendar.component(.day, from: rangeStart)
            let endYear = calendar.component(.year, from: endDisplay)
            let endMonth = calendar.component(.month, from: endDisplay)
            let endDay = calendar.component(.day, from: endDisplay)

            if startYear == endYear && startMonth == endMonth {
                return String(localized: "\(startYear)年\(startMonth)月\(startDay)日〜\(endDay)日")
            } else if startYear == endYear {
                return String(localized: "\(startYear)年\(startMonth)月\(startDay)日〜\(endMonth)月\(endDay)日")
            } else {
                return String(localized: "\(startYear)年\(startMonth)月\(startDay)日〜\(endYear)年\(endMonth)月\(endDay)日")
            }

        case .twelveMonths:
            let endDisplay = calendar.date(byAdding: .month, value: -1, to: rangeEnd) ?? rangeEnd
            let startYear = calendar.component(.year, from: rangeStart)
            let startMonth = calendar.component(.month, from: rangeStart)
            let endYear = calendar.component(.year, from: endDisplay)
            let endMonth = calendar.component(.month, from: endDisplay)

            if startYear == endYear {
                return String(localized: "\(startYear)年")
            } else {
                return String(localized: "\(startYear)年\(startMonth)月〜\(endYear)年\(endMonth)月")
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
    
    // 「今日」を含むページの適切なスクロール位置を計算する（今日/今月が右端に来る位置）。
    // タブを開く・開き直すたびに body 末尾の onAppear から呼ばれ、常に最近のページへ戻す。
    private func getTodayScrollPosition() -> Date {
        Self.todayScrollPosition(for: span)
    }
    
    // 可視範囲を日・月境界に揃えて取得（終了は排他的）
    // スクロール位置から表示範囲の基準日を求める。
    // 吸着位置の座標変換（オフセット⇔日付）にはわずかな浮動小数誤差が乗り、
    // 月初・週始まりのごく直前（例: 前月末の23:59:59）に静止することがある。
    // 生の値から月初や日境界を取ると1ページ前として集計されてしまうため、
    // 半日分ずらして日単位に丸めることで誤差を吸収する。
    private func errorToleratedScrollReference() -> Date {
        Calendar.current.startOfDay(for: scrollPos.addingTimeInterval(43_200))
    }

    private func alignedVisibleRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let reference = errorToleratedScrollReference()
        switch span {
        case .sevenDays:
            // 週の開始日（システム設定の週始まりの曜日）に丸めてから7日間を求める。
            // 月表示が(year, month)の単位でまとめて扱う（＝1ヶ月の途中でドラッグしても
            // 平均・合計は変わらず、月境界を跨いだ時だけ切り替わる）のと同じ考え方で、
            // 週表示も「その日から始まる7日間」ではなく「その日を含む暦週」を単位にする。
            // これにより、1ページ内をドラッグ中に平均・合計が日単位で目まぐるしく
            // 変わることがなくなり、週境界を跨いだ時だけ切り替わるようになる。
            let start = calendar.dateInterval(of: .weekOfYear, for: reference)?.start
                ?? calendar.startOfDay(for: reference)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, end)

        case .thirtyDays:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: reference))!
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return (start, end)
        case .twelveMonths:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: reference))!
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
                    HStack {
                        Text(dateRangeString)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
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
        }
    }

    // バーの不透明度を決める。
    // - バー選択中: 選択バケット以外を減光（既存挙動）
    // - 月表示: 31日固定幅の右端に入り込んだ「表示中の月に属さない日」（翌月分）は
    //   平均・合計・Y軸の集計に含まれないため、薄色にして対象外であることを示す
    private func barOpacity(for row: ChartRow, selectedBucketDate: Date?, monthRange: (start: Date, end: Date)?) -> Double {
        if let selectedBucketDate, row.bucketDate != selectedBucketDate {
            return 0.25
        }
        if let monthRange, !(monthRange.start <= row.bucketDate && row.bucketDate < monthRange.end) {
            return 0.35
        }
        return 1.0
    }

    @ViewBuilder
    private func createChart() -> some View {
        let selectedBucketDate = selectedDate.map { normalizedBucketDate(for: $0) }
        // 月表示のみ「表示中の月」の範囲を渡し、範囲外のバーを薄色表示する
        let visibleMonthRange: (start: Date, end: Date)? = (span == .thirtyDays) ? alignedVisibleRange() : nil
        Chart(sortedRowsForChart) { row in
            BarMark(
                x: .value("Period", row.bucketDate, unit: span.xUnit),
                y: .value("Minutes", row.durationMinutes)
            )
            .foregroundStyle(row.subjectColor)
            .opacity(barOpacity(for: row, selectedBucketDate: selectedBucketDate, monthRange: visibleMonthRange))
        }
        .chartScrollableAxes(.horizontal)
        // 記録の前後（今日を含む現在のページまで）も含む明示的なドメインを指定し、
        // データが存在しない期間へも確実にスクロールできるようにする
        .chartXScale(domain: chartXDomain)
        .chartScrollTargetBehavior(
            HealthStylePagingBehavior(span: span, domain: chartXDomain, monthAnchor: monthScrollAnchor)
        )
        .chartXVisibleDomain(length: currentVisibleLength)
        .chartScrollPosition(x: $scrollPos)
        // Y軸はスクロール中固定し、静止後（scheduleYAxisRecalc経由）に表示ページへフィットさせる
        .chartYScale(domain: 0...yAxisUpperBound)
        // Y軸上限を超えるバー（月表示の薄色の翌月分など）が上へ突き抜けず、
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
        .onChange(of: scrollPos) { _, newValue in
            scheduleYAxisRecalc()
            updateMonthScrollAnchorIfNeeded(newValue)
        }
        .accessibilityLabel("学習時間グラフ")
        .accessibilityValue("\(dateRangeString)、合計\(formatMinutesToHourMinute(totalStudyTimeInVisibleRange))")
    }

    // 月初ぴったりで静止した位置を、次のスワイプの吸着判定（進行方向）の基準として記録する。
    // 減速中の中間位置では更新せず、月初＝吸着完了位置とみなせる場合のみ書き込む。
    // 月初のごく直前に静止する浮動小数誤差を考慮し、半日ずらした日単位の丸めで月を求める。
    private func updateMonthScrollAnchorIfNeeded(_ position: Date) {
        guard span == .thirtyDays else { return }
        let calendar = Calendar.current
        let roundedDay = calendar.startOfDay(for: position.addingTimeInterval(43_200))
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: roundedDay)) ?? roundedDay
        if abs(position.timeIntervalSince(monthStart)) < 60 {
            monthScrollAnchor.value = monthStart
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
                // 月表示のスワイプ吸着判定の基準位置も現在の静止位置に同期する
                if span == .thirtyDays {
                    monthScrollAnchor.value = scrollPos
                }
                // データ読み込み直後は「静止後」の一種として即座にY軸を合わせる（待たずに反映）。
                // 初回表示時はアニメーションさせず、切替・再読み込み時のみ滑らかに遷移させる。
                yAxisRecalcTask?.cancel()
                recalculateYAxisDomain(animated: !isFirstLoad)
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

    // スパン切替時、切替前に見ていた表示範囲の代表日（中心付近）を含むページへ変換する
    // （例: 週→月なら、見ていた週を含む30日ページを表示）。
    // 変換結果は新しいスパンのページ境界に揃え、スクロール可能範囲内へクランプする。
    private func convertScrollPosition(_ position: Date, from oldSpan: ChartSpan, to newSpan: ChartSpan) -> Date {
        guard oldSpan != newSpan else { return position }

        let calendar = Calendar.current

        // 直前に見ていた範囲の中心付近の日付を基準にする
        let oldVisibleLength: TimeInterval
        switch oldSpan {
        case .sevenDays:
            oldVisibleLength = oldSpan.visibleLength
        case .thirtyDays, .twelveMonths:
            let months = (oldSpan == .twelveMonths) ? 12 : 1
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: position)) ?? position
            let monthEnd = calendar.date(byAdding: .month, value: months, to: monthStart) ?? monthStart
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

// MARK: - スクロール吸着挙動（ヘルスケア準拠のページング）

// スクロールが月初で静止した位置を保持する参照ボックス。
// chartScrollTargetBehavior のモディファイア値が毎フレーム変化すると
// 減速アニメーション中の再ターゲティングでガクつくため、参照型に包んで
// behavior の値自体は安定に保ったまま最新の静止位置を共有する。
// メインアクター（View）が書き込み、nonisolated な updateTarget が読むためロックで保護する。
private final class ChartScrollAnchor: @unchecked Sendable {
    private nonisolated let lock = NSLock()
    private nonisolated(unsafe) var storage: Date

    nonisolated init(_ value: Date) {
        storage = value
    }

    nonisolated var value: Date {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storage = newValue
        }
    }
}

// スパンごとに最適な吸着挙動へ委譲する。単一の型にまとめることで、
// スパン切替時にチャートのビュー階層（スクロール状態）を作り直さずに済む。
private struct HealthStylePagingBehavior: ChartScrollTargetBehavior {
    let span: ChartSpan
    // 月表示の月初吸着でスクロールオフセット⇔日付の変換に使う（データ変化時以外は不変）
    let domain: ClosedRange<Date>
    // 月表示で直前に静止していた月初（スワイプの進行方向判定の基準）
    let monthAnchor: ChartScrollAnchor

    nonisolated func updateTarget(_ target: inout ScrollTarget, context: ChartScrollTargetBehaviorContext) {
        switch span {
        case .sevenDays:
            // 週表示: 標準のページング挙動（フリック速度に応じて複数ページ動くこともある）。
            //
            // ジェスチャー開始位置を基準に「1ページを超える移動量だけ弱める」後処理を試みたが、
            // システムが計算したスクロールの減速アニメーションと、後から書き換えた目標位置が
            // 噛み合わずアニメーションがガクつく結果になったため撤回し、標準の挙動に戻している。
            PagingScrollTargetBehavior().updateTarget(&target, context: context)
        case .thirtyDays:
            // 月表示: ページ幅（31日固定）と月の長さ（28〜31日）が一致しないため、
            // 標準のページングや値吸着（ValueAligned）では左端が月初からずれた位置
            // （例: 右端が月初に揃う位置）に止まることがある。
            // そこで減速の自然な停止位置を日付へ変換し、「月の一定割合以上進んでいたら
            // 隣の月初へ、それ未満なら元の月初へ」というUIScrollViewのページング相当の
            // 判定で吸着先を計算する。どう転んでも必ずいずれかの月初に丸められる。
            updateTargetSnappingToMonthStart(&target, context: context)
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

    // 月表示用: 吸着先を必ず月初に揃える
    nonisolated private func updateTargetSnappingToMonthStart(
        _ target: inout ScrollTarget,
        context: ChartScrollTargetBehaviorContext
    ) {
        let contentWidth = Double(context.contentSize.width)
        let containerWidth = Double(context.containerSize.width)
        let domainSeconds = domain.upperBound.timeIntervalSince(domain.lowerBound)
        // 月表示の固定可視域（31日）。ChartSpan.visibleLength はMainActor分離のため
        // nonisolatedなこの文脈では参照できず、同じ値をリテラルで持つ。
        let visibleSeconds: TimeInterval = 86_400.0 * 31

        // 「コンテンツ全体の幅＝ドメイン全体」「コンテナ幅＝可視域31日分」という
        // 縮尺の前提が成り立っているか自己検証する（プロット領域のインセット等で
        // ずれている場合に誤った位置へ吸着させないため）。
        // 成り立たない場合は月初への値吸着にフォールバックする（左端ずれの可能性は
        // 残るが、動作は安全）。
        let secondsPerPoint = domainSeconds / max(contentWidth, 1)
        let expectedContainerWidth = visibleSeconds / secondsPerPoint
        let scaleLooksConsistent = contentWidth > 0 && containerWidth > 0 && domainSeconds > 0
            && abs(expectedContainerWidth - containerWidth) <= containerWidth * 0.05

        guard scaleLooksConsistent else {
            ValueAlignedChartScrollTargetBehavior(
                matching: DateComponents(day: 1),
                limitBehavior: .always
            ).updateTarget(&target, context: context)
            return
        }

        // 減速の自然な停止位置（速度反映済み）を日付に変換し、月初へ丸める
        let naturalDate = domain.lowerBound.addingTimeInterval(Double(target.rect.origin.x) * secondsPerPoint)
        let snapped = Self.snappedMonthStart(from: monthAnchor.value, naturalDate: naturalDate)
        target.rect.origin.x = CGFloat(snapped.timeIntervalSince(domain.lowerBound) / secondsPerPoint)
    }

    // ジェスチャーの自然な停止位置(naturalDate)を、直前に静止していた月初(start)からの
    // 進行方向を考慮して月初へ丸める。進行方向の月の一定割合（threshold）以上進んで
    // いれば隣の月初へ、それ未満なら手前の月初へ戻す（UIScrollViewのページング判定相当）。
    // どの経路でも必ず「いずれかの月初」を返すため、中途半端な位置には止まらない。
    nonisolated private static func snappedMonthStart(from start: Date, naturalDate: Date) -> Date {
        let calendar = Calendar.current
        // 月のこの割合を超えて進んだら隣の月へめくる（小さいほど軽いスワイプでめくれる）
        let threshold = 0.3
        // 基準位置を月初に正規化（許容誤差付きで記録された値の保険）
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start

        if naturalDate >= startMonth {
            var current = startMonth
            for _ in 0..<600 {
                guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { return current }
                if naturalDate < next {
                    let length = next.timeIntervalSince(current)
                    let progress = length > 0 ? naturalDate.timeIntervalSince(current) / length : 0
                    return progress >= threshold ? next : current
                }
                current = next
            }
            return current
        } else {
            var current = startMonth
            for _ in 0..<600 {
                guard let prev = calendar.date(byAdding: .month, value: -1, to: current) else { return current }
                if naturalDate >= prev {
                    let length = current.timeIntervalSince(prev)
                    let progress = length > 0 ? current.timeIntervalSince(naturalDate) / length : 0
                    return progress >= threshold ? prev : current
                }
                current = prev
            }
            return current
        }
    }
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
    
    var visibleLength: TimeInterval {
        let day = 86_400.0
        switch self {
        case .sevenDays: return day * 7
        case .thirtyDays:
            // 月表示は「月初を左端に31日分」の固定幅。31日に満たない月では翌月の
            // 先頭数日が右端に入り込むが、それらは集計対象外として薄色で表示する
            return day * 31
        case .twelveMonths:
            // 年表示の実際の可視域は月初からの12ヶ月分（うるう年等で日数が変動する）を
            // 動的に計算する（StudyTimeCharts.currentVisibleLength を参照）。
            // ここでは Calendar 計算に失敗した場合のフォールバック用の近似値（365日）を返す。
            return day * 365
        }
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
