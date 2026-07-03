//
// ScheduleRowView.swift
// Studies
//
// Created by kasahara takuma on 2025/08/13.
//

import SwiftUI

// MARK: - Schedule Row View

struct ScheduleRowView: View {
    let schedule: StudySchedule
    let onTap: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(schedule.uiColor)
                .frame(width: 4, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(schedule.name)
                        .font(.headline)
                        .fontWeight(.medium)

                    Spacer()
                    priorityBadge

                    Text("\(schedule.dailyGoalMinutes)分/日")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    if schedule.selectedWeekdays.isEmpty {
                        Text("適用曜日なし")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Calendar.localizedWeekdays().filter { schedule.selectedWeekdays.contains($0) }) { weekday in
                            Text(weekday.shortName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(schedule.uiColor)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    if !schedule.subjectGoals.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(schedule.subjectGoals.filter { $0.isEnabled }.prefix(3)) { subjectGoal in
                                Circle()
                                    .fill(subjectGoal.uiColor)
                                    .frame(width: 8, height: 8)
                            }

                            if schedule.subjectGoals.filter({ $0.isEnabled }).count > 3 {
                                Text("+\(schedule.subjectGoals.filter { $0.isEnabled }.count - 3)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .onTapGesture {
                // Toggle自体のタップを処理するため、何もしない
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete() } label: { Image(systemName: "trash") }
        }
    }

    private var priorityBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: priorityIcon)
                .font(.system(size: 10))
                .foregroundColor(priorityColor)
            Text(schedule.priorityText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(priorityColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(priorityColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var priorityIcon: String {
        switch schedule.priority {
        case 1: return "arrow.down.circle"
        case 2: return "arrow.down"
        case 3: return "minus"
        case 4: return "arrow.up"
        case 5: return "arrow.up.circle"
        default: return "minus"
        }
    }

    private var priorityColor: Color {
        switch schedule.priority {
        case 1: return .gray
        case 2: return .blue
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .orange
        }
    }
}
