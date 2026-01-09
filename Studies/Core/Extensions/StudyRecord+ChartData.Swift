//
// StudyRecord+ChartData.swift
// Studies - データ変換拡張
//

import Foundation
import SwiftUI

extension SevenDayChartData {
    /// Swift Charts用データに変換
    func toChartDataPoints() -> [ChartDataPoint] {
        var dataPoints: [ChartDataPoint] = []
        
        for dayData in dailyData {
            for subjectData in dayData.subjectData {
                let dataPoint = ChartDataPoint(
                    date: dayData.date,
                    subjectId: subjectData.subject.id,
                    subjectName: subjectData.subject.name,
                    subjectColor: subjectData.subject.color,
                    duration: subjectData.duration
                )
                dataPoints.append(dataPoint)
            }
        }
        
        return dataPoints
    }
}
