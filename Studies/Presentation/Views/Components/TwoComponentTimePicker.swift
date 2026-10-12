//
// TwoComponentTimePicker.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI
import UIKit

struct TwoComponentTimePicker: UIViewRepresentable {
    @Binding var hours: Int
    @Binding var minutes: Int
    var minuteStep: Int = 5

    private let hoursRange = Array(0..<24)
    private var minutesRange: [Int] { Array(stride(from: 0, through: 59, by: minuteStep)) }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator
        let hourRow = hoursRange.firstIndex(of: normalizedHours(hours)) ?? 0
        let minuteRow = minutesRange.firstIndex(of: normalizedMinutes(minutes)) ?? 0
        picker.selectRow(hourRow, inComponent: 0, animated: false)
        picker.selectRow(minuteRow, inComponent: 1, animated: false)
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        let hourRow = hoursRange.firstIndex(of: normalizedHours(hours)) ?? 0
        let minuteRow = minutesRange.firstIndex(of: normalizedMinutes(minutes)) ?? 0
        if uiView.selectedRow(inComponent: 0) != hourRow {
            uiView.selectRow(hourRow, inComponent: 0, animated: true)
        }
        if uiView.selectedRow(inComponent: 1) != minuteRow {
            uiView.selectRow(minuteRow, inComponent: 1, animated: true)
        }
    }

    private func normalizedHours(_ value: Int) -> Int {
        max(0, min(23, value))
    }

    private func normalizedMinutes(_ value: Int) -> Int {
        let clamped = max(0, min(59, value))
        return (clamped / max(1, minuteStep)) * max(1, minuteStep)
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate, UIPickerViewAccessibilityDelegate {
        var parent: TwoComponentTimePicker
        init(_ parent: TwoComponentTimePicker) { self.parent = parent }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            component == 0 ? parent.hoursRange.count : parent.minutesRange.count
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            if component == 0 {
                let h = parent.hoursRange[row]
                return String(localized: "\(h) 時間")
            } else {
                let m = parent.minutesRange[row]
                return String(localized: "\(m) 分")
            }
        }

        func pickerView(_ pickerView: UIPickerView, accessibilityLabelForComponent component: Int) -> String? {
            component == 0 ? String(localized: "時間") : String(localized: "分")
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if component == 0 {
                let h = parent.hoursRange[row]
                if parent.hours != h { parent.hours = h }
            } else {
                let m = parent.minutesRange[row]
                if parent.minutes != m { parent.minutes = m }
            }
        }
    }
}
