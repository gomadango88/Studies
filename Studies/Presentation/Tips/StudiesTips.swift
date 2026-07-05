//
// StudiesTips.swift
// Studies
//

import TipKit

enum StudiesTipsState {
    @Parameter
    static var hasCompletedOnboarding: Bool = false

    @Parameter
    static var hasSubjects: Bool = false
}

struct AddSubjectTip: Tip {
    var title: Text {
        Text("教材を追加しよう")
    }

    var message: Text? {
        Text("+ ボタンから最初の教材を登録しましょう。")
    }

    var image: Image? {
        Image(systemName: "plus.circle")
    }

    var rules: [Rule] {
        #Rule(StudiesTipsState.$hasCompletedOnboarding) { $0 == true }
    }
}

struct StartStudyTip: Tip {
    var title: Text {
        Text("タップで学習開始")
    }

    var message: Text? {
        Text("教材をタップするとストップウォッチが始まります。")
    }

    var image: Image? {
        Image(systemName: "stopwatch")
    }

    var rules: [Rule] {
        #Rule(StudiesTipsState.$hasCompletedOnboarding) { $0 == true }
        #Rule(StudiesTipsState.$hasSubjects) { $0 == true }
    }
}

struct SetGoalTip: Tip {
    var title: Text {
        Text("目標を設定しよう")
    }

    var message: Text? {
        Text("編集ボタンから週間目標と学習スケジュールを設定できます。")
    }

    var image: Image? {
        Image(systemName: "flag.fill")
    }

    var rules: [Rule] {
        #Rule(StudiesTipsState.$hasCompletedOnboarding) { $0 == true }
    }
}
