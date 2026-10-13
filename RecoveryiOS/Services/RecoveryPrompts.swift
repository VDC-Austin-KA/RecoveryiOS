import Foundation

/// System prompts per pathway plus the offline responder used when no API key is configured
/// or the network is unavailable.
enum RecoveryPrompts {
    static let groundingMarker = "[MODE:GROUNDING]"
    static let scheduleMarker = "[MODE:SCHEDULE]"

    static let base = """
    You are a warm, steady recovery companion inside a mobile app for people recovering from \
    alcohol, drug or other addictive patterns, and for their loved ones.

    Principles:
    - Be supportive, non-judgmental and trauma-informed. Never shame, lecture or moralize. \
    Relapse is part of many recovery journeys; respond to it with compassion and a next step.
    - Offer choices rather than commands, and respect the person's autonomy and pace.
    - Keep replies concise (under ~180 words) and practical, ending with one gentle question or next step.
    - You are not a therapist, doctor or sponsor. Encourage connection with a sponsor, peers, \
    a meeting or a professional when helpful.
    - Never give medical dosing advice. Withdrawal from alcohol, benzodiazepines or opioids can be \
    dangerous — direct people to medical care for detox questions.
    - If someone mentions suicide, self-harm, overdose or immediate danger, respond with care and \
    clearly share: call or text 988 (US Suicide & Crisis Lifeline), or call local emergency services.
    """

    static func system(for pathway: RecoveryPathway) -> String {
        "\(base)\n\n\(pathway.marker)\n\(guidance(for: pathway))"
    }

    static func guidance(for pathway: RecoveryPathway) -> String {
        switch pathway {
        case .twelveStep:
            return """
            Pathway: Traditional 12-Step framework. Use the language of the Steps, sponsorship, \
            meetings, service, "one day at a time" and a Higher Power of the person's own understanding. \
            Help with step-work reflection questions, resentment/fear inventories (the 4th-step columns: \
            who/what, the cause, what it affects, my part), nightly 10th-step reviews and pointing to \
            program literature without quoting long passages.
            """
        case .mindfulness:
            return """
            Pathway: Mindfulness and spiritual openness. Draw on present-moment awareness, breath work, \
            body scans, RAIN (Recognize, Allow, Investigate, Nurture), loving-kindness and urge surfing. \
            Be open to any spiritual or secular framing the person prefers.
            """
        case .gratitude:
            return """
            Pathway: Positive energy and gratitude. Use strengths-based, positive-psychology techniques: \
            gratitude lists, savoring, reframing, affirmations, celebrating small wins and building hope — \
            while still validating hard feelings rather than forcing positivity.
            """
        case .selfManagement:
            return """
            Pathway: Evidence-based self-management aligned with SMART Recovery and CBT. Use the 4-Point \
            Program (building motivation, coping with urges, managing thoughts/feelings/behaviors, living a \
            balanced life), the ABC tool, cost-benefit analysis, DISARM, urge surfing and cognitive \
            restructuring. Avoid 12-Step terminology unless the person uses it.
            """
        }
    }

    static func grounding(for pathway: RecoveryPathway) -> String {
        """
        \(system(for: pathway))
        \(groundingMarker)
        The person has pressed the urge/panic button and is in distress right now. Respond with a short, \
        calm, step-by-step grounding exercise (under 120 words). Use simple sentences, slow pacing and \
        second person. Remind them the urge will pass like a wave and suggest reaching out to someone.
        """
    }

    static func schedule(for pathway: RecoveryPathway) -> String {
        """
        \(system(for: pathway))
        \(scheduleMarker)
        You are acting as a daily schedule coach. Given the person's plan, give 3–5 short bullet points: \
        which recovery commitments to protect, risky gaps (idle evenings, isolation, HALT: hungry, angry, \
        lonely, tired) and one self-care suggestion. Do not repeat the whole schedule back.
        """
    }
}

enum MockResponder {
    static func reply(system: String, to input: String) -> String {
        let pathway = RecoveryPathway.allCases.first { system.contains($0.marker) } ?? .twelveStep
        if system.contains(RecoveryPrompts.groundingMarker) { return grounding(pathway) }
        if system.contains(RecoveryPrompts.scheduleMarker) { return scheduleTips }

        let text = input.lowercased()
        func mentions(_ words: [String]) -> Bool { words.contains { text.contains($0) } }

        if mentions(["suicid", "kill myself", "end it", "overdose", "hurt myself"]) {
            return """
            I'm really glad you told me. You deserve support right now from a real person. Please call or \
            text 988 (Suicide & Crisis Lifeline in the US) or your local emergency number. If you can, \
            reach out to your sponsor or someone you trust and let them know how you're feeling. \
            Would you be willing to make that call while I stay here with you?
            """
        }
        if mentions(["relapse", "slipped", "used again", "drank again", "picked up"]) {
            return relapse(pathway)
        }
        if mentions(["urge", "crav", "want to drink", "want to use", "tempt", "trigger"]) {
            return urge(pathway)
        }
        if mentions(["resent", "angry", "mad at", "furious"]) {
            return resentment(pathway)
        }
        if mentions(["step", "inventory", "sponsor"]) {
            return """
            Step work goes best one honest piece at a time. Try this: write down one person, place or \
            situation that's been on your mind, then note what happened, how it affected you (pride, \
            security, relationships) and — gently — what your part might have been. Then share it with \
            your sponsor or a trusted friend. Which piece feels most alive for you today?
            """
        }
        if mentions(["grateful", "gratitude", "thankful", "good day", "happy"]) {
            return """
            That's worth savoring. Take ten seconds to really notice it — where do you feel it in your body? \
            Writing three specific things you're grateful for tonight helps your brain find them again \
            tomorrow. What's one small win from today you'd like to remember?
            """
        }
        if mentions(["lonely", "alone", "isolat", "sad", "depress", "anxious", "anxiety", "scared"]) {
            return """
            That sounds heavy, and it makes sense you'd feel this way. You don't have to carry it alone. \
            A quick check: are you hungry, angry, lonely or tired right now? Taking care of one of those \
            can shift things a little. Is there one person you could text, or a meeting you could join \
            online in the next hour?
            """
        }
        return general(pathway)
    }

    static func urge(_ pathway: RecoveryPathway) -> String {
        switch pathway {
        case .twelveStep:
            return """
            Thank you for reaching out instead of acting on it — that's the program working. Urges peak and \
            pass, usually within 20–30 minutes. Right now: play the tape forward to how you'd feel tomorrow, \
            call your sponsor or someone from your home group, and say the Serenity Prayer slowly. Just for \
            the next hour, can you get to a meeting (in person or online)?
            """
        case .mindfulness:
            return """
            Let's surf this wave together. Breathe in for four, out for six. Notice where the urge lives in \
            your body — chest, throat, hands? Describe it with curiosity: its temperature, its shape. You \
            don't have to fight it or obey it; just watch it rise, crest and fall. What do you notice now?
            """
        case .gratitude:
            return """
            You're stronger than this moment — reaching out proves it. Name three things your sober self has \
            given you lately: maybe a clear morning, a conversation, money saved. Hold one of them in mind. \
            This craving is temporary; the life you're building isn't. Who could you share a win with today?
            """
        case .selfManagement:
            return """
            Good catch — noticing the urge is the first skill. Try DISARM: name the urge as a separate voice \
            ("that's my addictive voice talking"), then argue back with your cost-benefit list. Delay 15 \
            minutes and change your environment — walk, shower, call someone. What's one reason on your \
            "benefits of not using" list that matters most right now?
            """
        }
    }

    static func relapse(_ pathway: RecoveryPathway) -> String {
        """
        Thank you for being honest — that takes real courage, and it doesn't erase your progress. A lapse \
        is information, not a verdict. Right now, focus on safety: if you used something with withdrawal or \
        overdose risk, please get medical support. Then, when you're ready, let's look at what led up to it \
        so the next plan is stronger. Who is one person you can tell today?
        """
    }

    static func resentment(_ pathway: RecoveryPathway) -> String {
        switch pathway {
        case .twelveStep:
            return """
            Resentment is heavy to carry. Try the 4th-step columns: 1) who you're resentful at, 2) what \
            happened, 3) what it threatened in you (self-esteem, security, relationships), 4) your part, if \
            any. Then consider praying for or wishing that person well, even if you don't mean it yet. \
            Which column feels hardest?
            """
        case .selfManagement:
            return """
            Let's run an ABC: A — the activating event; B — the belief you're telling yourself about it; \
            C — the consequence (feelings, urges). Now dispute B: is it fully true? Is there another way to \
            see it? What's a more helpful belief you could try on?
            """
        default:
            return """
            Anger often protects something tender underneath — hurt, fear or disappointment. Take three slow \
            breaths, then ask: what do I need right now? You can set a boundary without carrying the poison. \
            What would letting go 5% look like today?
            """
        }
    }

    static func general(_ pathway: RecoveryPathway) -> String {
        switch pathway {
        case .twelveStep:
            return """
            I'm here with you. One day at a time — sometimes one hour at a time. A simple check-in: have you \
            connected with your sponsor or a meeting today, and is there a step or reading you're working \
            on? Tell me more about what's on your mind.
            """
        case .mindfulness:
            return """
            Let's pause together for one breath. Whatever you're carrying, it's welcome here without \
            judgment. What are you noticing in your mind and body right now?
            """
        case .gratitude:
            return """
            I'm glad you're here — showing up for yourself counts. What's one thing, however small, that went \
            right today? Let's build from there.
            """
        case .selfManagement:
            return """
            Thanks for checking in. Which of the four areas feels most relevant right now: motivation, \
            coping with urges, managing thoughts and feelings, or building a balanced life? We can pick one \
            tool and practice it.
            """
        }
    }

    static func grounding(_ pathway: RecoveryPathway) -> String {
        """
        You're safe in this moment. Let's slow down together.

        1. Plant your feet on the floor. Feel the ground holding you.
        2. Breathe in through your nose for 4… hold for 4… out slowly for 6.
        3. Look around and name five things you can see.
        4. Press your palms together and notice the warmth and pressure.
        5. Remind yourself: "This is an urge. It will rise, peak and pass."

        You've gotten through every hard moment so far. When you're ready, reach out to one person — \
        you don't have to do this alone.
        """
    }

    static let scheduleTips = """
    • Protect your recovery anchors first — morning reflection, your meeting and the nightly review are \
    non-negotiable.
    • Watch for unstructured evening time; plan a call, meeting or activity for that window.
    • HALT check: schedule real meals and a wind-down so you're not hungry or tired at risky times.
    • Leave 15-minute buffers between commitments so you're not rushing.
    • Add one small act of self-care you'd genuinely enjoy.
    """
}
