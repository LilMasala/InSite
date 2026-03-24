import SwiftUI
import Foundation

public struct CommunityHub: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var appeared = false

    public init() {}

    private var accent: Color { themeManager.theme.accent }

    public var body: some View {
        ZStack {
            // Same animated gradient background you use on Home
            BreathingBackground(theme: themeManager.theme).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: appeared)

                    VStack(spacing: 12) {
                        NavigationLink {
                            CommunityBoardView(accent: accent)
                        } label: {
                            FeatureTile(
                                icon: "text.bubble.fill",
                                title: "Community Board",
                                subtitle: "Anonymous posts • upvotes • time filters",
                                accent: accent
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            CrosswordsHome(accent: accent)
                        } label: {
                            FeatureTile(
                                icon: "square.grid.3x3.fill.square",
                                title: "Crosswords",
                                subtitle: "Standard puzzles + community maker",
                                accent: accent
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    aboutCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if !appeared { appeared = true } }
    }

    // MARK: - Pieces

    private var headerCard: some View {
        Card {
            HStack(spacing: 10) {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome").font(.headline)
                    Text("Connect, vent, and have some fun — anonymously.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .tint(accent)
    }

    private var aboutCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("About")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("The Community Board is anonymous and uses lightweight upvotes with time filters (Today, 7d, 30d). Crosswords let you play standard puzzles and build weekly community-made ones from user-submitted clues.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Shared building blocks

fileprivate struct FeatureTile: View {
    var icon: String
    var title: String
    var subtitle: String
    var accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.12))
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }
}

fileprivate struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.06)))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }
}

// MARK: - Previews
struct CommunityHub_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack { CommunityHub() }
                .environmentObject(ThemeManager())
                .environment(\.colorScheme, .light)

            NavigationStack { CommunityHub() }
                .environmentObject(ThemeManager())
                .environment(\.colorScheme, .dark)
        }
    }
}
