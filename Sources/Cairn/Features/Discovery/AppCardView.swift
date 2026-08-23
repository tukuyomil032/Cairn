import SwiftUI

/// カテゴリグリッドの1カード。アプリ名/開発者/star数/言語カラードット/subTagsチップを表示する。
///
/// コンテンツ層のためLiquid Glassは使わず不透明背景（`docs/design/colors-and-materials.md`の
/// `card-bg`相当）を敷く。ホバー時のわずかな浮き上がりはフィードバック目的のモーションで、
/// Reduce Motion有効時は無効化する。
struct AppCardView: View {
    var repository: CachedRepository

    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var developerName: String {
        repository.fullName.split(separator: "/").first.map(String.init) ?? repository.fullName
    }

    private var appName: String {
        repository.fullName.split(separator: "/").last.map(String.init) ?? repository.fullName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                appIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(appName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(developerName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(formattedStarCount)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(languageColor)
                    .frame(width: 8, height: 8)
                Text(repository.primaryLanguage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if !repository.subTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(repository.subTags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12), in: .capsule)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(Color.primary.opacity(0.07))
        )
        .scaleEffect(isHovering ? 1.015 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.7), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var appIcon: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(languageColor.opacity(0.85))
            .frame(width: 36, height: 36)
            .overlay(
                Text(appName.prefix(1).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    private var languageColor: Color {
        appEnvironment.linguistColors.color(for: repository.primaryLanguage) ?? Color.secondary
    }

    private var formattedStarCount: String {
        if repository.starCount >= 1000 {
            return String(format: "%.1fk", Double(repository.starCount) / 1000)
        }
        return String(repository.starCount)
    }
}
