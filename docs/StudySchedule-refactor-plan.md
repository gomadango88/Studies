# StudySchedule.swift 分割リファクタ計画

`Studies/Presentation/Views/StudySchedule.swift`(約1,280行・17型)を層と責務ごとにファイル分割する。
**動作変更は一切行わない**(型の移動・ファイル分割・不要import削除のみ)。

## 進め方のルール

- 各フェーズ完了ごとに typecheck(下記コマンド)で0エラーを確認して **1コミット**。どのフェーズ間で中断しても安全な状態を保つ。
- 途中で中断した場合、このファイルのチェックリストとgit logを見て未完了フェーズから再開する。
- 元ファイルの basename(`StudySchedule.swift`)は最終フェーズの `git mv` まで維持する(同名ファイルの一時共存を避けるため、エンティティ抽出は最後)。
- コミットメッセージは日本語1行+`Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` トレーラー。

## フェーズ

- [x] **Phase 1**: `TwoComponentTimePicker`(UIViewRepresentable、StudySessionViewからも使用される共有部品)を `Studies/Presentation/Views/Components/TwoComponentTimePicker.swift` へ抽出
- [x] **Phase 2**: `ScheduleViewModel` を `Studies/Presentation/ViewModels/ScheduleViewModel.swift` へ抽出
- [x] **Phase 3**: エディタ系Viewを抽出
  - `ScheduleEditorView`(+ private の `ScheduleFormSnapshot`/`SubjectGoalKey`)と `WeekdayToggleButton` → `Studies/Presentation/Views/Schedule/ScheduleEditorView.swift`("Schedule Editor" の `#Preview` も移動)
  - `SubjectGoalEditorView` と `SubjectGoalRow` → `Studies/Presentation/Views/Schedule/SubjectGoalEditorView.swift`
- [x] **Phase 4**: メイン画面を抽出
  - `WeeklyGoalScheduleView` → `Studies/Presentation/Views/Schedule/WeeklyGoalScheduleView.swift`(メインの `#Preview` も移動)
  - `ScheduleRowView` → `Studies/Presentation/Views/Schedule/ScheduleRowView.swift`
  - 任意: `WeeklyGoalScheduleView` 内の private `localizedWeekdays` は既存の `Calendar.localizedWeekdays()` と数学的に同一((firstWeekday+6)%7 ≡ firstWeekday-1)なので、extension呼び出しに置き換えて重複を削除してよい
- [ ] **Phase 5**: 残ったエンティティを分割して元ファイルを解消
  - `git mv Studies/Presentation/Views/StudySchedule.swift Studies/Domain/Entities/StudySchedule.swift`(`StudySchedule` と `SubjectGoal` を残す)
  - `Weekday` + `Calendar.localizedWeekdays()` extension → `Studies/Domain/Entities/Weekday.swift`(新規)
  - `CodableColor` → `Studies/Domain/Entities/CodableColor.swift`(新規)
  - 各ファイルの不要import(WidgetKit/SwiftData/os等)を整理

## やらないこと(将来の課題)

- `priorityText`/`priorityColor` が `StudySchedule`・`ScheduleRowView`・`ScheduleEditorView` に三重実装されている問題の統合(動作変更を伴わないが、今回のスコープ外)
- ScheduleViewModel の `saveSchedules()` 空メソッド削除などのAPI整理

## 検証コマンド

アプリターゲット(0エラーであること):
```
cd "/Users/takuma/Library/Mobile Documents/com~apple~CloudDocs/Studies" && xcrun swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -target arm64-apple-ios26.0-simulator -swift-version 5 -default-isolation MainActor -enable-upcoming-feature MemberImportVisibility $(find Studies -name '*.swift') StudiesLiveActivity/StudyActivityAttributes.swift StudiesWidget/StudyGoalWidgetData.swift 2>&1 | grep -E "error:" | head -20
```

備考:
- プロジェクトは fileSystemSynchronizedGroups 構成のため、ディスク上のファイル作成・移動だけでXcodeに反映される(pbxproj編集不要)
- この環境ではシミュレータランタイム未インストールのため xcodebuild は不可。typecheckで検証する
- 各フェーズのコミットにはこの計画ファイルのチェックボックス更新も含める
