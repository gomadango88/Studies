//
//  WeekdayMaskTests.swift
//  StudiesTests
//
//  Set<Weekday>.mask / Int.toWeekdaySet() のラウンドトリップテスト。
//

import Testing
@testable import Studies

struct WeekdayMaskTests {

    @Test func mask_allWeekdays_roundTrips() {
        let all = Set(Weekday.allCases)
        let mask = all.mask
        let restored = mask.toWeekdaySet()
        #expect(restored == all)
    }

    @Test func mask_emptySet_roundTrips() {
        let empty: Set<Weekday> = []
        let mask = empty.mask
        #expect(mask == 0)
        #expect(mask.toWeekdaySet().isEmpty)
    }

    @Test func mask_singleWeekday_sunday_roundTrips() {
        let single: Set<Weekday> = [.sunday]
        let mask = single.mask
        #expect(mask == 1) // 1 << 0
        #expect(mask.toWeekdaySet() == single)
    }

    @Test func mask_singleWeekday_saturday_roundTrips() {
        let single: Set<Weekday> = [.saturday]
        let mask = single.mask
        #expect(mask == (1 << 6))
        #expect(mask.toWeekdaySet() == single)
    }

    @Test func mask_weekdaysOnly_roundTrips() {
        let weekdaysOnly: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let mask = weekdaysOnly.mask
        #expect(mask.toWeekdaySet() == weekdaysOnly)
    }

    @Test func mask_arbitrarySubset_roundTrips() {
        let subset: Set<Weekday> = [.sunday, .wednesday, .saturday]
        let mask = subset.mask
        #expect(mask.toWeekdaySet() == subset)
    }

    @Test func toWeekdaySet_ignoresBitsOutsideWeekdayRange() {
        // Weekdayのrawvalueは0...6なので、それ以外のビットは無視されるべき
        let maskWithExtraBits = 0b1111_1111 // 8ビット全て立っているが有効なのは下位7ビット
        let restored = maskWithExtraBits.toWeekdaySet()
        #expect(restored == Set(Weekday.allCases))
    }
}
