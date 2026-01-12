# Studies — 学習時間を「見える化」するシンプルな学習記録アプリ

SwiftUI と SwiftData で作られた、学習時間の記録・目標管理・進捗可視化を行う iOS アプリです。ストップウォッチ計測と手入力の両方に対応し、Live Activity とウィジェットで「いまの学習」や「今日の目標達成度」をホーム画面から素早く確認できます。

- 対応プラットフォーム: iOS
- 最低要件の目安: iOS 17 以降（SwiftData/Observation を使用）
- 使用技術: SwiftUI, SwiftData, ActivityKit, WidgetKit, AppIntents, App Groups


## 主な機能

- 学習記録
  - 教材（科目）ごとに学習時間を記録
  - ストップウォッチ計測＋手入力の両対応
  - アプリ終了時もセッション状態を自動復元
- 目標管理
  - 曜日別の目標時間、教材別の目標時間
  - 同じ曜日で競合する複数目標を優先度で管理
  - 連続学習日数（ストリーク）を自動計算
- 可視化
  - 今日の合計時間・達成率・連続日数の表示
  - 教材別の進捗（今日/週/月）をカードで表示
  - 統計・履歴タブでの振り返り
- Live Activity / ウィジェット
  - ロック画面/Dynamic Islandに学習経過を表示
  - ホーム画面ウィジェットで「今日の目標/達成度/ストリーク」を表示
  - AppIntents 経由のクイック操作（再開/停止 等）
- 使いやすさ
  - 教材ピン留め・並べ替え・スワイプ操作（ピン/削除）
  - 検索バーで教材名を素早くフィルタ
  - 触覚フィードバック、Liquid Glass対応

## アーキテクチャ

- UI: SwiftUI（@Observable/Observation を使用）
- DI: `DIContainer` による ModelContainer/Repository/UseCase の Lazy 生成
- レイヤリング
  - View → ViewModel → UseCase → Repository → SwiftData
- セッション/計測
  - `EfficientStopwatchManager` による省電力ストップウォッチ（10秒間隔 + tolerance）
  - `StudyActivityManager` による ActivityKit 連携（開始/更新/終了 + 重複防止）
  - アプリ終了/拡張間での状態引き継ぎを考慮（アクティブセッション保存 + Live Activity 用の軽量状態）


## 主要コンポーネント

- 画面/ルート
  - `ContentView.swift`: タブ構成、ディープリンク、ウィジェット更新の起点
  - `SubjectListView.swift`: 教材一覧（ピン留め/並べ替え/検索/追加/削除）
  - `StudySessionView.swift`: 学習セッション（ストップウォッチ＋手入力、強制終了検出/復元）
  - `GoalSettingPreview` / `StudyGoal.swift`: 目標/進捗表示、関連 ViewModel
  - `StatisticsView` / `TimelineView`: 集計・履歴（本プロジェクト内の既存ビューに準拠）
- セッション/Live Activity
  - `EfficientStopwatchManager.swift`: 省電力ストップウォッチ、状態保存/復元
  - `StudyActivityManager.swift`: ActivityKit の開始/更新/終了、定期更新（10秒）
  - `StudySessionState.swift` / `StudySessionManager`: アクティブセッションの保存/復元（`@AppStorage`）
- データ/DI
  - `DIContainer.swift`: `ModelContainer` / Repository / UseCase を集中管理
  - `SubjectModel.swift` / `StudyRecordModel.swift`: SwiftData の @Model 定義
  - `SubjectRepository.swift` / `StudyRecordRepository.swift`: SwiftData CRUD
  - `SubjectUseCase.swift` / `StudyRecordUseCase.swift`: 集計/検証/アーカイブ等のドメインロジック
- ウィジェット/Intents
  - `StudyGoalWidgetData.swift`: App Groups 経由のデータ共有（`WidgetDataManager`）
  - `ResumeStudyIntent` / `StopStudyIntent`: Live Activity 操作用 AppIntents
  - `UpdateActivityIntent`: 背景更新用の Intent スタブ
  - `StudiesLiveActivityControl`: Control Widget の例（AppIntentControlConfiguration）


## データモデル（概要）

- Subject（教材）
  - `id`, `name`, `color(RGBA)`, `sortOrder`, `isPinned`, `createdAt`
- StudyRecord（学習記録）
  - `id`, `subjectId`, `studyDate`, `duration(秒)`, `createdAt`, `isArchived`
- ウィジェット共有データ（`WidgetStudyGoalData`）
  - `dailyGoal`, `todayMinutes`, `streakDays`, `lastUpdated`（`isAchieved` を算出）


## ディープリンク

以下のカスタム URL スキームでアプリ内ナビゲーションが可能です。

- studies://studygoal         // 目標タブへ（互換リンク）
- studies://tab/record        // 記録タブへ
- studies://tab/stats         // 統計タブへ
- studies://tab/goals         // 目標タブへ
- studies://tab/history       // 履歴タブへ
