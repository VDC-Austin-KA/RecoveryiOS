# Recovery — iOS recovery companion

A native SwiftUI app (iOS 17+) supporting people in recovery: a live meeting finder across
AA, NA, HA, SMART Recovery and Al-Anon, an adaptive AI recovery assistant, an AI day planner with
Apple Calendar sync, a sobriety counter with milestones, an urge "panic button" and an encrypted journal.

**Works out of the box.** No API keys, accounts or config files are required: meetings come from public
listings, the assistant runs on Apple Intelligence or a built-in offline companion, and Codemagic builds a
sideloadable IPA on every push. **Zero third-party dependencies** — Apple frameworks only.

| Tab | What it does |
| --- | --- |
| **Today** | Sobriety counter (days, hours, money and time saved), milestone badges with celebration, daily quote, pathway affirmation, media picks, big **"I'm having an urge"** button, today's plan progress |
| **Meetings** | Live listings on a MapKit map and list; filters by fellowship, in-person/virtual and "today"; search; Zoom links, directions, add-to-calendar, favorites; offline cache; links to every fellowship's official finder |
| **Assistant** | Pathway-specific, trauma-informed chat (12-Step, Mindfulness, Gratitude, SMART/CBT); free on-device or OpenRouter AI; "Continue in Claude / ChatGPT" to use your own subscription; optional API keys |
| **Planner** | Timeline with completion toggles and progress rings; AI planner turns "work 9-5, AA at 7:30pm, call sponsor" into a recovery-first schedule with coach notes; one-tap EventKit sync |
| **Tools** | 12-Step work with prompts, nightly inventory, gratitude journal, journal history (AES-GCM encrypted, Face ID lock), sponsor & emergency contacts, hotlines, settings |

The urge-support screen (box breathing, 5-4-3-2-1 grounding, one-tap calls to sponsor/contacts,
988/SAMHSA hotlines and an AI grounding script) is reachable from the toolbar of every tab.

## Install (Codemagic → Sideloadly)

1. Codemagic builds `RecoveryiOS-unsigned.ipa` on every push to any branch (workflow **iOS unsigned IPA**)
   and emails the result. No Apple account, certificates or environment variables are needed in Codemagic.
2. Download the IPA from the build's **Artifacts** and install it with [Sideloadly](https://sideloadly.io)
   or AltStore, which sign it with your Apple ID.

Bundle identifier: `com.vdcaustin.recoveryios` (Sideloadly may append a suffix for free Apple IDs).

## Meeting data

| Fellowship | Source | Notes |
| --- | --- | --- |
| AA | [Online Intergroup of AA](https://aa-intergroup.org/meetings/) feed (worldwide online meetings) + Meeting Guide/TSML feeds of NYC, Austin, Phoenix, Seattle and SF/Marin intergroups | Regional feeds download only when you're within 150 km; hashed `tsml-cache-*.json` names are re-discovered from each intergroup's page |
| NA | [BMLT aggregator](https://aggregator.bmltenabled.org) | Worldwide, queried by your location (~100 nearest meetings) |
| Al-Anon | Data behind [al-anon.org's meeting finder](https://al-anon.org/al-anon-meetings/find-an-al-anon-meeting/) | ~13 MB, refreshed weekly, filtered to 80 km |
| HA, SMART | No public data exists | The Meetings list links to their official finders (plus AA, NA, Al-Anon and Al-Anon electronic meetings) |

Downloads are cached in `Caches/MeetingFeeds` (6 h – 7 days per source) and stale copies are used when
offline. Meetings you open or favorite are also kept in SwiftData. If nothing can load at all, sample
meetings are shown so the screen is never empty. Extra Meeting Guide feeds can be added with the
`MEETING_FEED_*` keys below.

## AI assistant: free options and subscriptions

| Option | Cost | How |
| --- | --- | --- |
| Apple Intelligence (on-device) | Free | Automatic on iOS 26 iPhones with Apple Intelligence enabled |
| OpenRouter free models | Free | Tools › Settings › **Sign in with OpenRouter** — OAuth PKCE login; the key is created and stored automatically |
| Claude Pro / ChatGPT Plus subscription | Your plan | Assistant menu › **Continue in Claude / ChatGPT** opens the conversation in the official app on your subscription (the prompt is also copied to the clipboard) |
| Own API key | Pay-as-you-go | Paste or password-manager autofill in Settings (Keychain storage) |
| Offline companion | Free | Always available; used whenever nothing else is |

Why no "log in with Claude/ChatGPT" inside the app: Anthropic does not permit third-party apps to offer
Claude.ai login or route requests through Free/Pro/Max credentials
([policy](https://code.claude.com/docs/en/legal-and-compliance)), and OpenAI's "Sign in with ChatGPT"
plan sharing is limited to approved partners. Handing off to the official apps is the supported way to use
those subscriptions.

## Project structure

```
RecoveryiOS.xcodeproj/            Xcode 16+ project (synchronized folders — new files are picked up automatically)
RecoveryiOS/
  App/                            @main app, dependency container (AppServices), tab root
  Core/                           Configuration loader (plist + env), Keychain wrapper
  Models/                         Domain types and SwiftData @Models
  Services/
    MeetingSources.swift          LiveMeetingProvider · TSML/OMLA, BMLT and Al-Anon sources · on-disk FeedCache
    MeetingProvider.swift         MeetingProvider protocol · OMLA decoder · MockMeetingProvider
    LLMClient.swift               LLMClient protocol · Anthropic/OpenAI clients · MockLLMClient · LLMFactory
    OpenRouter.swift              OpenRouter OAuth PKCE sign-in and free-model client
    OnDeviceLLM.swift             Apple Intelligence (FoundationModels) client
    SubscriptionHandoff.swift     "Continue in Claude / ChatGPT" links
    RecoveryPrompts.swift         Per-pathway system prompts and the offline responder
    ScheduleAssistant.swift       Local day-plan parser + recovery anchors
    CalendarService.swift · LocationService.swift · JournalCrypto.swift · InspirationEngine.swift
  Features/                       Dashboard, Meetings, Assistant, Planner, Urge, Tools (Views + @Observable ViewModels)
  Shared/                         Reusable components
RecoveryiOSTests/                 XCTest suite (no network)
Support/                          Info.plist, entitlements, Configuration.example.plist
scripts/                          generate_config.sh · ci_test.sh · ci_build_ipa.sh
codemagic.yaml                    Test + unsigned IPA workflow
```

## Optional configuration

Nothing here is required. For development builds you can bake in keys or extra feeds:

```bash
cp .env.example .env          # fill in what you want; leave the rest blank
./scripts/generate_config.sh  # writes RecoveryiOS/Resources/Configuration.plist (git-ignored)
```

Keys: `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, `OPENAI_API_KEY`, `OPENAI_MODEL`, `MEETING_FEED_AA` …
`MEETING_FEED_ALANON`. Environment variables in the Xcode scheme override the plist, and keys entered in
the app override both. Anything baked into the plist ships inside the app, so don't use it for shared builds.

## Building locally

Xcode 16+ (Xcode 26 for Apple Intelligence support). Open `RecoveryiOS.xcodeproj`, pick an iPhone
simulator, ⌘R. `./scripts/ci_test.sh` runs the same tests as CI.

## Privacy & safety

- Journal entries are AES-GCM encrypted with a Keychain key (this device only); optional Face ID lock.
- Location is used only to find nearby meetings; calendar access is write-only.
- Prompts are supportive, non-judgmental and trauma-informed, avoid medical dosing advice and surface 988
  for crisis language. The app is a peer-support tool, not medical care.
