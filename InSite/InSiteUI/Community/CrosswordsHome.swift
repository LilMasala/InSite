import SwiftUI

public struct CrosswordsHome: View {
    @EnvironmentObject private var themeManager: ThemeManager
    public var accent: Color
    @State private var tab = 1 // start on Community Maker by default

    public init(accent: Color) { self.accent = accent }

    public var body: some View {
        ZStack {
            BreathingBackground(theme: themeManager.theme).ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("Mode", selection: $tab) {
                    Text("Standard").tag(0)
                    Text("Community Maker").tag(1)
                    Text("Daily Puzzle").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    if tab == 0 {
                        StandardCrosswordPlaceholder(accent: accent)
                    } else if tab == 1 {
                        CrosswordMakerView(accent: accent)
                    } else {
                        DailyCrosswordView(accent: accent)
                    }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Crosswords")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StandardCrosswordPlaceholder: View {
    var accent: Color
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.fill.square")
                .font(.largeTitle)
                .foregroundStyle(accent)
            Text("Standard Crossword")
                .font(.headline)
            Text("We’ll plug in a provider later (NYT is closed; consider PuzzleMe or an open-source generator).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(0.06)))
    }
}



struct CrosswordsHome_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                CrosswordsHome(accent: .blue)
                    .environmentObject(ThemeManager())
            }
            .environment(\.colorScheme, .light)

            NavigationStack {
                CrosswordsHome(accent: .pink)
                    .environmentObject(ThemeManager())
            }
            .environment(\.colorScheme, .dark)
        }
    }
}
