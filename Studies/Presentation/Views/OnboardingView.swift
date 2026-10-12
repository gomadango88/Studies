//
// OnboardingView.swift
// Studies
//

import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    private struct Feature: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let description: String
        let tint: Color
    }

    private let features: [Feature] = [
        Feature(symbol: "stopwatch", title: String(localized: "学習時間を記録"), description: String(localized: "教材ごとにストップウォッチで学習を記録できます"), tint: .orange),
        Feature(symbol: "chart.bar", title: String(localized: "学習を振り返る"), description: String(localized: "日・週・月の学習時間をグラフで振り返れます"), tint: .blue),
        Feature(symbol: "flag.fill", title: String(localized: "目標を管理"), description: String(localized: "週間目標と学習スケジュールを設定できます"), tint: .green),
        Feature(symbol: "platter.filled.top.iphone", title: String(localized: "ロック画面にも対応"), description: String(localized: "ロック画面のLive Activityとウィジェットで進捗を確認できます"), tint: .purple)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    header

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(features) { feature in
                            featureRow(feature)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 40)
                .padding(.bottom, 24)
            }

            continueButton
        }
        .background(Color(.systemBackground))
    }

    private var header: some View {
        VStack(spacing: 16) {
            appIconImage
                .frame(width: 80, height: 80)

            Text("Studiesへようこそ")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var appIconImage: some View {
        if let uiImage = Self.bundleAppIcon() {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentColor.gradient)
        }
    }

    // アプリアイコン(Icon Composer製の"icon"型アセット)はApp Icon専用タイプで登録されており、
    // Image(_:)/UIImage(named:)の通常検索では見つからない。CFBundleIconFilesが指す
    // ビルド生成済みのフラット化PNG(通常のバンドルリソース)を辿って取得する。
    private static func bundleAppIcon() -> UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let iconName = files.last
        else { return nil }

        return UIImage(named: iconName)
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: feature.symbol)
                .font(.title2)
                .foregroundStyle(feature.tint)
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feature.title)、\(feature.description)")
    }

    private var continueButton: some View {
        Button {
            onComplete()
        } label: {
            Text("続ける")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
