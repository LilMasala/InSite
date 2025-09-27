import SwiftUI

private enum Region: CaseIterable {
    case arm, abdomen, butt, thigh

    /// Top → bottom of body
    static var ordered: [Region] { [.arm, .abdomen, .butt, .thigh] }

    var title: String {
        switch self {
        case .arm: return "Arm"
        case .abdomen: return "Abdomen"
        case .butt: return "Butt"
        case .thigh: return "Thigh"
        }
    }

    /// Display strings for left/right
    func label(isLeft: Bool) -> String {
        let side = isLeft ? "Left" : "Right"
        return "\(side) \(title)"
    }
}

struct SiteChangeUI: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var sharedData = SiteChangeData.shared

    @State private var showAlert = false
    @State private var pendingSelection: (region: Region, isLeft: Bool)? = nil

    // background
    private var bg: some View {
        LinearGradient(
            colors: [
                themeManager.theme.bgStart,
                themeManager.theme.bgEnd
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Title card
                HStack(spacing: 12) {
                    Image("BearBlue")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose location")
                            .font(.title3.weight(.semibold))
                        Text("Pick your current infusion site")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Rows ordered by body height
                VStack(spacing: 12) {
                    ForEach(Region.ordered, id: \.self) { region in
                        Row(region: region,
                            accent: themeManager.theme.accent,
                            choose: { isLeft in
                                pendingSelection = (region, isLeft)
                                showAlert = true
                            })
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Status
                HStack(spacing: 8) {
                    Circle().fill(themeManager.theme.accent).frame(width: 8, height: 8)
                    Text("Current: \(sharedData.siteChangeLocation)")
                        .font(.subheadline)
                    Spacer()
                    let daysLeft = max(0, 3 - sharedData.daysSinceSiteChange)
                    Text("\(daysLeft) day\(daysLeft == 1 ? "" : "s") until change")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityElement(children: .combine)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .frame(maxWidth: 700)               // keeps it elegant on iPad/Mac
            .frame(maxWidth: .infinity)
        }
        .background(bg)
        .navigationTitle("Site Change")
        .alert("Change Site", isPresented: $showAlert) {
            Button("Change", role: .destructive) {
                guard let p = pendingSelection else { return }
                let loc = p.region.label(isLeft: p.isLeft)     // e.g. “Left Butt”
                sharedData.setSiteChange(location: loc)
                HealthDataUploader().recordSiteChange(location: loc, localTz: .current, backfillDays: 14)
            }
            Button("Cancel", role: .cancel) { pendingSelection = nil }
        } message: {
            Text("Are you sure you want to change site to \(pendingSelection.map { $0.region.label(isLeft: $0.isLeft) } ?? "")?")
        }
    }
}

// MARK: - Row with paired Left / Right buttons

private struct Row: View {
    let region: Region
    let accent: Color
    let choose: (Bool) -> Void  // isLeft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(region.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                SitePill(title: region.label(isLeft: true),  accent: accent)  { choose(true) }
                SitePill(title: region.label(isLeft: false), accent: accent)  { choose(false) }
            }
        }
    }
}

private struct SitePill: View {
    var title: String
    var accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}



#Preview {
    NavigationStack {
        SiteChangeUI()
            .environmentObject(ThemeManager())   // inject theme
            .environmentObject(SiteChangeData.shared) // if you make it conform to ObservableObject
    }
}
