import SwiftUI

extension Fellowship {
    var color: Color {
        switch self {
        case .aa: .blue
        case .na: .teal
        case .ha: .purple
        case .smart: .orange
        case .alAnon: .pink
        }
    }
}

extension TaskCategory {
    var color: Color {
        switch self {
        case .reflection: .orange
        case .meeting: .blue
        case .stepWork: .purple
        case .sponsor: .green
        case .selfCare: .pink
        case .work: .gray
        case .other: .teal
        }
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// Compact toolbar entry point to the urge/panic screen, available from every tab.
struct UrgeToolbarButton: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        Button {
            services.showUrgeSupport = true
        } label: {
            Label("Urge Support", systemImage: "lifepreserver.fill")
        }
        .tint(.red)
        .accessibilityHint("Opens grounding exercises and emergency contacts")
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = .green

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring, value: progress)
        }
    }
}

struct Hotline: Identifiable {
    let name: String
    let detail: String
    let url: URL

    var id: String { name }

    static let all: [Hotline] = [
        Hotline(name: "988 Suicide & Crisis Lifeline", detail: "Call or text 988 (US) — 24/7", url: URL(string: "tel:988")!),
        Hotline(name: "SAMHSA National Helpline", detail: "1-800-662-4357 — free, confidential, 24/7", url: URL(string: "tel:18006624357")!),
        Hotline(name: "Crisis Text Line", detail: "Text HOME to 741741", url: URL(string: "sms:741741&body=HOME")!),
        Hotline(name: "Emergency Services", detail: "Call 911 for immediate danger", url: URL(string: "tel:911")!),
    ]
}
