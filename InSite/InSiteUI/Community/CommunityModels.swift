import SwiftUI
import Combine
import Foundation

// Simple shared types & the tile (kept here so Home imports only Community)
public struct CommunityTile: View {
    public var accent: Color
    @ScaledMetric private var diameter: CGFloat = 140

    public init(accent: Color) { self.accent = accent }

    public var body: some View {
        CircleTileBase(diameter: diameter) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(accent.opacity(0.10))
                    Image(systemName: "person.3.sequence.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(accent)
                }
                .frame(height: 54)

                Text("Community")
                    .font(.subheadline.weight(.semibold))

                Text("Board • Crosswords")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .accessibilityLabel("Community: board and crosswords")
    }
}

// MARK: - Board models

public enum BoardWindow: String, CaseIterable, Identifiable {
    case today = "Today", week = "Last 7 Days", month = "Last 30 Days"
    public var id: String { rawValue }
    public var interval: TimeInterval {
        switch self {
        case .today: return 60*60*24
        case .week:  return 60*60*24*7
        case .month: return 60*60*24*30
        }
    }
}

public struct CommunityPost: Identifiable, Hashable {
    public let id = UUID()
    public var text: String
    public var createdAt: Date
    public var upvotes: Int
    public var comments: Int
}

public final class CommunityBoardVM: ObservableObject {
    @Published public var window: BoardWindow = .today
    @Published public var posts: [CommunityPost] = sample

    public init() {}

    public func upvote(_ post: CommunityPost) {
        guard let idx = posts.firstIndex(of: post) else { return }
        posts[idx].upvotes += 1
    }

    public var filteredSorted: [CommunityPost] {
        let cutoff = Date().addingTimeInterval(-window.interval)
        return posts
            .filter { $0.createdAt >= cutoff }
            .sorted { l, r in
                (l.upvotes, l.createdAt) > (r.upvotes, r.createdAt)
            }
    }
    // In CommunityBoardVM
    func removeUpvote(_ post: CommunityPost) {
        guard let idx = posts.firstIndex(of: post) else { return }
        posts[idx].upvotes = max(0, posts[idx].upvotes - 1)
    }

    // Optional: sorting toggle support (kept simple)
    var sortTop: Bool = true {
        didSet {
            // If you want "New" sorting:
            if !sortTop {
                posts.sort { $0.createdAt > $1.createdAt }
            }
        }
    }

    func refresh() {
        // hook for .refreshable(), no-op for now
    }


    private static let sample: [CommunityPost] = [
        .init(text: "CGM screamed at 3am; cat also screamed. We vibed.", createdAt: Date().addingTimeInterval(-60*30), upvotes: 21, comments: 3),
        .init(text: "Pre-bolus before exam stress (learned the hard way).", createdAt: Date().addingTimeInterval(-60*60*3), upvotes: 15, comments: 2),
        .init(text: "Site change: warm skin + calm podcast = fewer ouches.", createdAt: Date().addingTimeInterval(-60*60*26), upvotes: 8, comments: 1),
        .init(text: "Favorite hypo snack that isn’t chalky?", createdAt: Date().addingTimeInterval(-60*60*50), upvotes: 12, comments: 9),
    ]
}

// MARK: - Crosswords models

//public struct QA: Identifiable, Hashable {
//    public let id = UUID()
//    public var clue: String
//    public var answer: String
//}
//
//public final class CrosswordMakerVM: ObservableObject {
//    @Published public var pairs: [QA] = []
//    @Published public var clue: String = ""
//    @Published public var answer: String = ""
//
//    public func addPair() {
//        let c = clue.trimmingCharacters(in: .whitespacesAndNewlines)
//        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !c.isEmpty, !a.isEmpty else { return }
//        pairs.append(QA(clue: c, answer: a.uppercased().replacingOccurrences(of: " ", with: "")))
//        clue = ""; answer = ""
//    }
//
//    public var previewRows: [String] {
//        pairs.map { "\($0.answer) — \($0.clue)" }
//    }
//}
