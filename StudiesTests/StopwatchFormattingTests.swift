//
//  StopwatchFormattingTests.swift
//  StudiesTests
//
//  EfficientStopwatchManagerの時間フォーマットと状態設定に関するテスト。
//  start()/stop()はDate()依存かつUserDefaultsを触るシングルトンへの副作用があるため対象外とし、
//  フォーマットとsetAccumulatedTime/setElapsedTime/stopwatchStartDateの挙動のみを検証する。
//

import Testing
@testable import Studies

@MainActor
struct StopwatchFormattingTests {

    // MARK: - formattedTime

    @Test func formattedTime_zeroSeconds() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(0)
        #expect(manager.formattedTime == "00:00")
    }

    @Test func formattedTime_59Seconds() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(59)
        #expect(manager.formattedTime == "00:59")
    }

    @Test func formattedTime_exactly1Minute() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(60)
        #expect(manager.formattedTime == "01:00")
    }

    @Test func formattedTime_minutesAndSeconds() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(125) // 2分5秒
        #expect(manager.formattedTime == "02:05")
    }

    @Test func formattedTime_exactly1Hour() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(3600)
        #expect(manager.formattedTime == "1:00:00")
    }

    @Test func formattedTime_justBelow1Hour() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(3599) // 59分59秒
        #expect(manager.formattedTime == "59:59")
    }

    @Test func formattedTime_over10Hours() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(37_265) // 10時間21分5秒
        #expect(manager.formattedTime == "10:21:05")
    }

    @Test func formattedTime_hoursMinutesSeconds() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(3725) // 1時間2分5秒
        #expect(manager.formattedTime == "1:02:05")
    }

    // MARK: - formattedTimeWithoutSeconds

    @Test func formattedTimeWithoutSeconds_zero() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(0)
        #expect(manager.formattedTimeWithoutSeconds == "0:--")
    }

    @Test func formattedTimeWithoutSeconds_underOneHour() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(125) // 2分5秒
        #expect(manager.formattedTimeWithoutSeconds == "2:--")
    }

    @Test func formattedTimeWithoutSeconds_exactly1Hour() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(3600)
        #expect(manager.formattedTimeWithoutSeconds == "1:00:--")
    }

    @Test func formattedTimeWithoutSeconds_over10Hours() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(37_265) // 10時間21分5秒
        #expect(manager.formattedTimeWithoutSeconds == "10:21:--")
    }

    // MARK: - setAccumulatedTime / setElapsedTime

    @Test func setAccumulatedTime_doesNotAffectElapsedTime() {
        let manager = EfficientStopwatchManager()
        manager.setAccumulatedTime(120)
        // accumulatedTimeを設定しただけではelapsedTimeは変わらない（updateElapsedTimeを経由しないため）
        #expect(manager.accumulatedTime == 120)
        #expect(manager.elapsedTime == 0)
    }

    @Test func setElapsedTime_updatesElapsedTimeOnly() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(300)
        #expect(manager.elapsedTime == 300)
        #expect(manager.accumulatedTime == 0)
        #expect(manager.formattedTime == "05:00")
    }

    @Test func setAccumulatedTime_andElapsedTime_independent() {
        let manager = EfficientStopwatchManager()
        manager.setAccumulatedTime(60)
        manager.setElapsedTime(90)
        #expect(manager.accumulatedTime == 60)
        #expect(manager.elapsedTime == 90)
    }

    // MARK: - stopwatchStartDate

    @Test func stopwatchStartDate_nilWhenNotRunning() {
        let manager = EfficientStopwatchManager()
        // start()を呼んでいない（isRunning == false）ためstartDateは常にnil
        #expect(manager.stopwatchStartDate == nil)
    }

    @Test func stopwatchStartDate_nilAfterSettingElapsedTimeWithoutRunning() {
        let manager = EfficientStopwatchManager()
        manager.setElapsedTime(500)
        manager.setAccumulatedTime(500)
        // isRunningがfalseのままなのでstartDateはnilのまま
        #expect(manager.stopwatchStartDate == nil)
        #expect(manager.isRunning == false)
    }
}
