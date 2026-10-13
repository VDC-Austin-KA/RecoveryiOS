# Recovery — iOS recovery companion

A native SwiftUI app (iOS 17+) supporting people in recovery: a nearby meeting finder across
AA, NA, HA, SMART Recovery and Al-Anon, an adaptive AI recovery assistant, an AI day planner with
Apple Calendar sync, a sobriety counter with milestones, an urge "panic button" and an encrypted journal.

**Zero third-party dependencies.** Everything uses Apple frameworks (SwiftUI, SwiftData, MapKit,
CoreLocation, EventKit, CryptoKit, LocalAuthentication), so Codemagic builds don't depend on SPM.
**Offline-first.** Every feature works without a network or API key. Meetings fall back to a SwiftData
cache, the assistant to an on-device responder, and the planner parses your day locally.

| Tab | What it does |
| --- | --- |
| **Today** | Sobriety counter (days, hours, money and time saved), milestone badges with celebration, daily quote, pathway affirmation, media picks, big **"I'm having an urge"** button, today's plan progress |
| **Meetings** | MapKit map with your location and color-coded pins, plus a list view; filters by fellowship, in-person/virtual and "today"; search; detail with Zoom link, directions, add-to-calendar and favorites (cached offline) |
| **Assistant** | Chat with pathway-specific, trauma-informed system prompts (12-Step, Mindfulness, Gratitude, SMART/CBT); BYO Anthropic/OpenAI key; offline fallback; persisted history |
| **Planner** | Timeline with completion toggles and progress rings (all tasks + recovery commitments); AI planner turns "work 9-5, AA at 7:30pm, call sponsor" into a recovery-first schedule and coach notes; one-tap EventKit sync |
| **Tools** | 12-Step work with prompts, nightly inventory, gratitude journal, journal history (AES-GCM encrypted, Face ID lock), sponsor & emergency contacts, hotlines, settings |

The urge-support screen (box breathing, 5-4-3-2-1 grounding, one-tap calls to sponsor/contacts,
988/SAMHSA hotlines and an AI grounding script) is reachable from the toolbar of every tab.

## Project structure

```
RecoveryiOS.xcodeproj/            Xcode 16 project (synchronized folders — new files are picked up automatically)
  xcshareddata/xcschemes/         Shared "RecoveryiOS" scheme (required for CI)
RecoveryiOS/
  App/                            @main app, dependency container (AppServices), tab root
  Core/                           Configuration loader (plist + env), Keychain wrapper
  Models/                         Domain types (Meeting, Fellowship, RecoveryPathway, Milestone…) and SwiftData @Models
  Services/
    MeetingProvider.swift         MeetingProvider protocol · MeetingGuideProvider (OMLA JSON) · MockMeetingProvider
    LLMClient.swift               LLMClient protocol · AnthropicClient · OpenAIClient · MockLLMClient · LLMFactory
    RecoveryPrompts.swift         Per-pathway system prompts, grounding/schedule prompts, offline MockResponder
    ScheduleAssistant.swift       Local day-plan parser + recovery anchors
    CalendarService.swift         EventKit write-only export
    LocationService.swift         CoreLocation wrapper (@Observable)
    JournalCrypto.swift           AES-GCM journal cipher + Face ID lock
    InspirationEngine.swift       Daily quotes, affirmations, media suggestions
  Features/                       Dashboard, Meetings, Assistant, Planner, Urge, Tools — Views + @Observable ViewModels
  Shared/                         Reusable components (cards, progress ring, hotlines, urge button)
  Resources/Assets.xcassets       App icon, accent color
RecoveryiOSTests/                 XCTest unit tests (stats, OMLA decoding, planner, prompts, config, crypto)
Support/                          Info.plist, entitlements, Configuration.example.plist
scripts/                          generate_config.sh · ci_test.sh · ci_archive_unsigned.sh
codemagic.yaml                    CI (tests + unsigned archive) and release (TestFlight) workflows
```

Architecture is MVVM with SwiftUI's Observation framework: views own `@Observable` view models via
`@State`, persistence is SwiftData (`@Query` in views, `ModelContext` passed into view-model actions),
and services sit behind protocols (`MeetingProvider`, `LLMClient`) with mock implementations so the
app and its tests run with no network or credentials.

## Configuration & API keys

Keys are resolved in this order — the first non-empty value wins (values starting with `YOUR_` are ignored):

1. **In-app Settings** (Tools › Settings › AI assistant) — stored in the iOS Keychain. Recommended for real users.
2. **Environment variables** — set in the Xcode scheme (*Edit Scheme › Run › Arguments*) for local development.
3. **`RecoveryiOS/Resources/Configuration.plist`** — git-ignored; generate it from `.env`:

```bash
cp .env.example .env        # fill in what you have; leave the rest blank
./scripts/generate_config.sh
```

| Key | Purpose |
| --- | --- |
| `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` | Claude via the Messages API (default model `claude-sonnet-5-5`) |
| `OPENAI_API_KEY`, `OPENAI_MODEL` | OpenAI Chat Completions (default `gpt-4o-mini`) |
| `MEETING_FEED_AA` … `MEETING_FEED_ALANON` | Meeting Guide / OMLA JSON feed URL per fellowship |

With no AI key the assistant uses the offline companion; with no meeting feeds the map shows sample
meetings around you. Provider choice (Automatic / Anthropic / OpenAI / Offline) is in Settings.

> **Security note:** anything baked into `Configuration.plist` ships inside the app bundle and can be
> extracted. Use it for development/test builds; for production prefer per-user keys in Settings or a
> backend proxy that holds the key.

### Meeting feeds

`MeetingGuideProvider` reads the [Meeting Guide / OMLA spec](https://github.com/code4recovery/spec)
JSON that most TSML (12 Step Meeting List) and Code for Recovery sites publish. The decoder tolerates
the common variants (`day` as int/array/string, coordinates as numbers or strings, `attendance_option`,
`conference_url`). Meetings within 80 km of the user are shown; online meetings are always included.
Anything the user opens is cached in SwiftData, and favorites remain available offline.

## Building locally

Requirements: Xcode 16 or newer (the project uses synchronized folder groups, object version 77).

```bash
open RecoveryiOS.xcodeproj          # choose the RecoveryiOS scheme and an iPhone simulator, ⌘R
./scripts/ci_test.sh                # same unit-test run as CI
```

Set your team under *Signing & Capabilities* to run on a device. Change the bundle identifier
`com.recoveryapp.RecoveryiOS` to one you own before shipping.

Developing from WSL/Linux: all sources are plain text and the project never needs regenerating —
add a `.swift` file anywhere under `RecoveryiOS/` and Xcode/Codemagic pick it up automatically.
The `scripts/` are POSIX bash and run on Linux (config generation) or macOS (build/test).

## Codemagic setup

1. In [Codemagic](https://codemagic.io), **Add application** → connect GitHub → select `RecoveryiOS`
   → choose **codemagic.yaml** as the configuration.
2. **`ios-ci`** runs automatically on every push and pull request. It needs no credentials:
   it generates `Configuration.plist`, runs the unit tests on the newest iOS 17+ simulator (JUnit report
   shown in the build UI), and produces `RecoveryiOS-unsigned.xcarchive.zip` as an artifact.
3. *(Optional)* To include API keys/feeds in CI builds, create an environment variable group named
   `recovery_api_keys` (mark keys **secret**) and uncomment the `groups` block in `ios-ci`.
4. **`ios-release`** (triggered by pushing a tag like `v1.0.0`) builds a signed IPA and uploads it to TestFlight:
   - *Teams › Integrations › Developer Portal*: add an App Store Connect API key named `Codemagic API Key`.
   - *Code signing identities*: upload or auto-generate an **App Store** distribution certificate and a
     provisioning profile for your bundle id.
   - Create the `recovery_api_keys` group (it may be empty) and set `APP_STORE_APPLE_ID` in
     `codemagic.yaml` to your app's Apple ID.
   - Update `bundle_identifier` (and `PRODUCT_BUNDLE_IDENTIFIER` in Xcode) to your own id.

## Tests

`RecoveryiOSTests` covers sobriety math and milestones, OMLA feed decoding (including edge cases),
mock meeting filtering, next-meeting date math, the schedule parser and recovery anchors, pathway
prompts and the offline responder (including crisis escalation), configuration precedence, provider
fallback, daily inspiration rotation and journal encryption (round trip, tamper and wrong-key detection).
No test touches the network.

## Privacy & safety

- Journal entries are encrypted with AES-GCM; the key lives in the Keychain (`ThisDeviceOnly`).
  Optional Face ID/passcode lock re-engages whenever the app goes to the background.
- Location is used only to find nearby meetings. Calendar access is write-only.
- AI prompts are supportive, non-judgmental and trauma-informed, avoid medical dosing advice and
  always surface 988 for crisis language. The app is a peer-support tool, not medical care.
