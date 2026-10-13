import Foundation

struct Quote: Hashable {
    let text: String
    let author: String
}

struct MediaSuggestion: Identifiable, Hashable {
    let title: String
    let subtitle: String
    let icon: String
    let url: URL

    var id: String { title }
}

/// Rotates a quote, affirmation and media picks per calendar day — fully offline.
enum InspirationEngine {
    static let quotes: [Quote] = [
        Quote(text: "One day at a time.", author: "Recovery slogan"),
        Quote(text: "God grant me the serenity to accept the things I cannot change, courage to change the things I can, and wisdom to know the difference.", author: "Serenity Prayer"),
        Quote(text: "The journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
        Quote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
        Quote(text: "Fall seven times, stand up eight.", author: "Japanese proverb"),
        Quote(text: "Progress, not perfection.", author: "Recovery slogan"),
        Quote(text: "The wound is the place where the light enters you.", author: "Rumi"),
        Quote(text: "Act as if what you do makes a difference. It does.", author: "William James"),
        Quote(text: "Almost everything will work again if you unplug it for a few minutes, including you.", author: "Anne Lamott"),
        Quote(text: "Rock bottom became the solid foundation on which I rebuilt my life.", author: "J.K. Rowling"),
        Quote(text: "Feelings are not facts.", author: "Recovery slogan"),
        Quote(text: "Smooth seas do not make skillful sailors.", author: "Proverb"),
        Quote(text: "This too shall pass.", author: "Persian adage"),
        Quote(text: "Courage doesn't always roar. Sometimes courage is the quiet voice at the end of the day saying, 'I will try again tomorrow.'", author: "Mary Anne Radmacher"),
        Quote(text: "Keep coming back. It works if you work it.", author: "Recovery slogan"),
    ]

    static let affirmations: [RecoveryPathway: [String]] = [
        .twelveStep: [
            "Today I don't have to do this alone.",
            "I am exactly where I need to be on my journey.",
            "Just for today, I choose recovery.",
            "I let go of what I can't control and act on what I can.",
            "Service to others keeps me grounded.",
        ],
        .mindfulness: [
            "This moment is enough, and so am I.",
            "I can feel an urge without acting on it.",
            "Each breath is a fresh start.",
            "I meet my thoughts with curiosity, not judgment.",
            "Peace is available to me right here.",
        ],
        .gratitude: [
            "I am grateful for the clarity sobriety gives me.",
            "Small wins add up to a new life.",
            "I deserve the good things coming my way.",
            "My energy is precious, and I spend it on what heals.",
            "Today I celebrate how far I've come.",
        ],
        .selfManagement: [
            "I am in charge of my choices.",
            "Urges are temporary; my goals are lasting.",
            "I can challenge unhelpful thoughts with evidence.",
            "Every healthy choice builds a balanced life.",
            "I have tools, and I know how to use them.",
        ],
    ]

    static let media: [MediaSuggestion] = [
        suggestion("5-Minute Box Breathing", "Calm the nervous system fast", "wind", "guided box breathing 5 minutes"),
        suggestion("Urge Surfing Meditation", "Ride out cravings mindfully", "water.waves", "urge surfing guided meditation addiction"),
        suggestion("Recovery Speaker Stories", "Hope from people who've been there", "person.wave.2.fill", "recovery speaker meeting story"),
        suggestion("Body Scan for Sleep", "Wind down for a restful night", "moon.zzz.fill", "body scan meditation for sleep"),
        suggestion("Gratitude Meditation", "Shift into appreciation", "heart.circle.fill", "gratitude meditation 10 minutes"),
        suggestion("SMART Recovery Tools", "CBT skills for change", "brain.head.profile", "SMART Recovery tools explained"),
    ]

    private static func suggestion(_ title: String, _ subtitle: String, _ icon: String, _ query: String) -> MediaSuggestion {
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: query)]
        return MediaSuggestion(title: title, subtitle: subtitle, icon: icon, url: components.url!)
    }

    static func dayIndex(_ date: Date) -> Int {
        Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    static func quote(for date: Date = .now) -> Quote {
        quotes[dayIndex(date) % quotes.count]
    }

    static func affirmation(for date: Date = .now, pathway: RecoveryPathway) -> String {
        let list = affirmations[pathway] ?? affirmations[.twelveStep] ?? ["One day at a time."]
        return list[dayIndex(date) % list.count]
    }

    static func mediaPicks(for date: Date = .now, count: Int = 2) -> [MediaSuggestion] {
        let start = dayIndex(date) % media.count
        return (0..<min(count, media.count)).map { media[(start + $0) % media.count] }
    }
}
