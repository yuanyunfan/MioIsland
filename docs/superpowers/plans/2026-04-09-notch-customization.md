# CodeIsland Notch Customization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship seven user-facing notch customization features (buddy/usage-bar toggles, in-place live edit mode for resizing, horizontal slide along top edge, six theme presets, idle auto-shrink with max-width, four-step font scale) as CodeIsland v1.10.0.

**Architecture:** Centralized `NotchCustomizationStore` (`ObservableObject`) holds a single `Codable` value type persisted under `notchCustomization.v1`. All customization-aware views read from the store via `@EnvironmentObject`. Live edit mode is delivered as a separate auxiliary `NSPanel` (`NotchLiveEditPanel`) with a `contentView.hitTest(_:)` override for menu-bar pass-through. The theme system introduces `NotchPalette` + six preset lookups; color transitions are scoped to dedicated modifiers (`NotchPaletteModifier`, `NotchSecondaryForegroundModifier`) so geometry springs are not retriggered by theme switches. Hardware notch detection uses `NSScreen.safeAreaInsets` with a user-facing `auto | forceVirtual` override.

**Tech Stack:** Swift 5/6, SwiftUI + AppKit hybrid, Xcode 16+, `XCTest` / Swift Testing, Codable + UserDefaults, `OSLog` for diagnostics.

**Spec:** `/Users/ying/Documents/AI/CodeIsland/docs/superpowers/specs/2026-04-08-notch-customization-design.md`

**Execution context:**
- Brainstorming was run directly on `main`; no pre-existing worktree. Before starting execution, the implementer SHOULD create a dedicated worktree off the current `main` (e.g. `git worktree add ../CodeIsland-notch-customization -b feature/notch-customization main`) so implementation does not pollute `main` until PR time.
- All file paths in this plan are relative to the CodeIsland repo root.

**Target version:** `v1.10.0` (pre-release `v1.10.0-rc1` while Apple notarization case 102860621331 is still open).

---

## Chunk 1: Foundation — Color helper, state model, store, tests

This chunk lands the entire persistence layer before any UI change. At
the end of the chunk, the app compiles and runs exactly as before, but
a new `NotchCustomizationStore` singleton is alive in the process, its
state persists across launches, and legacy `usePixelCat` has been
migrated. No user-visible change yet.

### Task 1.1: Lift `Color(hex:)` helper into its own file

**Files:**
- Create: `ClaudeIsland/UI/Helpers/Color+Hex.swift`
- Modify: `ClaudeIsland/Services/Session/BuddyReader.swift` (remove the existing extension, lines 16–31)
- Xcode project: add `Color+Hex.swift` to the `ClaudeIsland` target

- [ ] **Step 1: Read the existing `Color(hex:)` implementation**

```bash
sed -n '10,35p' ClaudeIsland/Services/Session/BuddyReader.swift
```

Expected: see an `extension Color { init(hex: String) { ... } }`
somewhere in that range. Copy the whole `extension Color { ... }`
block verbatim for the next step.

- [ ] **Step 2: Create the new file with the lifted extension**

Create `ClaudeIsland/UI/Helpers/Color+Hex.swift`:

```swift
//
//  Color+Hex.swift
//  ClaudeIsland
//
//  Hex-string Color initializer. Originally defined inside
//  BuddyReader.swift; lifted here so palette code elsewhere in the
//  app can use it without importing BuddyReader. Behavior is
//  identical to the original — no API change.
//

import SwiftUI

extension Color {
    /// Create a `Color` from a 6- or 8-character hex string, e.g.
    /// `Color(hex: "CAFF00")` or `Color(hex: "CAFF00FF")`. Missing
    /// alpha defaults to `1.0`. Leading `#` is accepted and stripped.
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var rgba: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgba)
        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((rgba >> 16) & 0xFF) / 255.0
            g = Double((rgba >> 8) & 0xFF) / 255.0
            b = Double(rgba & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((rgba >> 24) & 0xFF) / 255.0
            g = Double((rgba >> 16) & 0xFF) / 255.0
            b = Double((rgba >> 8) & 0xFF) / 255.0
            a = Double(rgba & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1.0
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
```

**NOTE:** The exact bit-shifting body of the extension in
`BuddyReader.swift` may differ slightly (e.g., it may support only
6-character strings and may not handle `#` prefix). **Copy the
original body verbatim** in your implementation rather than using
the snippet above if they differ, so you do not introduce a
behavior change.

- [ ] **Step 3: Delete the extension from `BuddyReader.swift`**

Open `ClaudeIsland/Services/Session/BuddyReader.swift`, locate the
`extension Color { init(hex: String) ... }` block, and delete it
entirely. Do not touch any other code in the file.

- [ ] **Step 4: Add the new file to the Xcode target**

In Xcode: right-click `ClaudeIsland/UI/Helpers/` in the project
navigator → "Add Files to ClaudeIsland…" → select
`Color+Hex.swift` → ensure "ClaudeIsland" target is checked.

If `UI/Helpers/` doesn't exist as a group yet, create it first (right-
click `ClaudeIsland/UI/` → New Group → "Helpers").

- [ ] **Step 5: Build and verify nothing broke**

Run:

```bash
xcodebuild -scheme ClaudeIsland -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. Any existing call sites that used
`Color(hex: ...)` (there are 5 in `BuddyReader.swift`'s
`rarity.color`) must still compile because the extension is now
globally available from `UI/Helpers/Color+Hex.swift`.

- [ ] **Step 6: Commit**

```bash
git add ClaudeIsland/UI/Helpers/Color+Hex.swift \
        ClaudeIsland/Services/Session/BuddyReader.swift \
        ClaudeIsland.xcodeproj/project.pbxproj
git commit -m "refactor: lift Color(hex:) to UI/Helpers/Color+Hex.swift

Moved verbatim from BuddyReader.swift so palette code elsewhere in
the app can use it without importing BuddyReader. Behavior and API
are unchanged. Paves the way for the notch customization feature
which needs the helper at multiple call sites."
```

---

### Task 1.2: Define the `NotchCustomization` value type + enums

**Files:**
- Create: `ClaudeIsland/Models/NotchCustomization.swift`
- Xcode project: add to `ClaudeIsland` target

- [ ] **Step 1: Create the file with the full type definition**

```swift
//
//  NotchCustomization.swift
//  ClaudeIsland
//
//  Single value type holding every user-adjustable notch setting.
//  Persisted atomically by NotchCustomizationStore under the
//  UserDefaults key `notchCustomization.v1`. See
//  docs/superpowers/specs/2026-04-08-notch-customization-design.md
//  for the full architectural rationale.
//

import CoreGraphics
import Foundation

struct NotchCustomization: Codable, Equatable {
    // Appearance
    var theme: NotchThemeID = .classic
    var fontScale: FontScale = .default

    // Visibility toggles
    var showBuddy: Bool = true
    var showUsageBar: Bool = true

    // Geometry — all user-controlled via live edit mode.
    /// Upper bound for auto-expand. Idle content shrinks below this;
    /// long content expands up to this and truncates beyond.
    var maxWidth: CGFloat = 440
    /// Signed horizontal offset from the screen's center (pinned to top).
    /// Render-time clamped; stored value preserved for later screen changes.
    var horizontalOffset: CGFloat = 0

    // Hardware notch override
    var hardwareNotchMode: HardwareNotchMode = .auto

    static let `default` = NotchCustomization()
}

/// Identifier for one of the six built-in themes. Raw string values
/// so persisted JSON is stable across code renames.
enum NotchThemeID: String, Codable, CaseIterable, Identifiable {
    case classic
    case paper
    case neonLime
    case cyber
    case mint
    case sunset

    var id: String { rawValue }
}

/// Four-step relative font scale. String raw values for stable
/// persistence; `CGFloat` multiplier exposed via computed property
/// so we avoid the historical fragility of `Codable` on `CGFloat`
/// raw values.
enum FontScale: String, Codable, CaseIterable {
    case small    = "small"
    case `default` = "default"
    case large    = "large"
    case xLarge   = "xLarge"

    var multiplier: CGFloat {
        switch self {
        case .small:    return 0.85
        case .default:  return 1.0
        case .large:    return 1.15
        case .xLarge:   return 1.3
        }
    }
}

/// How CodeIsland treats the MacBook's physical notch when
/// computing the panel geometry.
///
/// `auto` — detect via `NSScreen.main?.safeAreaInsets.top > 0`.
/// `forceVirtual` — ignore any hardware notch and draw a
///   virtual, user-positionable overlay (useful on external
///   displays or when the user prefers a freely-resized notch
///   even on a notched Mac).
enum HardwareNotchMode: String, Codable {
    case auto
    case forceVirtual
}
```

- [ ] **Step 2: Add the new file to the Xcode target**

Right-click `ClaudeIsland/Models/` in Xcode → "Add Files to
ClaudeIsland…" → select `NotchCustomization.swift` → ensure target
membership.

- [ ] **Step 3: Build to verify the types compile**

```bash
xcodebuild -scheme ClaudeIsland -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ClaudeIsland/Models/NotchCustomization.swift \
        ClaudeIsland.xcodeproj/project.pbxproj
git commit -m "feat(notch): add NotchCustomization value type and enums

Centralized state for the notch customization feature. One Codable
struct holds every user-adjustable field (theme, font scale,
visibility toggles, max width, horizontal offset, hardware mode) so
the store can persist it as a single atomic blob under
notchCustomization.v1.

FontScale uses String raw values + a computed CGFloat multiplier
instead of CGFloat raw values to keep Codable round-tripping safe.

See docs/superpowers/specs/2026-04-08-notch-customization-design.md
sections 5.1-5.2."
```

---

### Task 1.3: Write unit tests for `NotchCustomization` (Codable, defaults, enums)

**Files:**
- Create: `ClaudeIslandTests/NotchCustomizationTests.swift`
- Xcode project: add to `ClaudeIslandTests` target

- [ ] **Step 1: Write the failing tests**

Create `ClaudeIslandTests/NotchCustomizationTests.swift`:

```swift
//
//  NotchCustomizationTests.swift
//  ClaudeIslandTests
//

import XCTest
@testable import ClaudeIsland

final class NotchCustomizationTests: XCTestCase {

    // MARK: - Defaults

    func test_default_hasExpectedValues() {
        let c = NotchCustomization.default
        XCTAssertEqual(c.theme, .classic)
        XCTAssertEqual(c.fontScale, .default)
        XCTAssertTrue(c.showBuddy)
        XCTAssertTrue(c.showUsageBar)
        XCTAssertEqual(c.maxWidth, 440)
        XCTAssertEqual(c.horizontalOffset, 0)
        XCTAssertEqual(c.hardwareNotchMode, .auto)
    }

    // MARK: - Codable roundtrip

    func test_codable_roundtripPreservesAllFields() throws {
        var original = NotchCustomization.default
        original.theme = .neonLime
        original.fontScale = .large
        original.showBuddy = false
        original.showUsageBar = false
        original.maxWidth = 520
        original.horizontalOffset = -42
        original.hardwareNotchMode = .forceVirtual

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NotchCustomization.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func test_codable_decodingMissingFieldsFailsCleanly() throws {
        // Older versions of the stored blob may be missing fields we
        // add later. We prefer to have decoding FAIL so migration is
        // explicit — any new field addition requires bumping the
        // UserDefaults key suffix or handling the default-fallback in
        // the store, not silently papering over it at the Codable
        // layer. This test documents that intent.
        let partialJSON = """
        {"theme": "classic"}
        """
        XCTAssertThrowsError(
            try JSONDecoder().decode(NotchCustomization.self, from: Data(partialJSON.utf8))
        )
    }

    // MARK: - FontScale

    func test_fontScale_multiplierMapping() {
        XCTAssertEqual(FontScale.small.multiplier,   0.85)
        XCTAssertEqual(FontScale.default.multiplier, 1.0)
        XCTAssertEqual(FontScale.large.multiplier,   1.15)
        XCTAssertEqual(FontScale.xLarge.multiplier,  1.3)
    }

    func test_fontScale_rawValueStability() {
        // These raw strings are persisted. Renaming any case is a
        // breaking change that requires a migration, so we pin them
        // here to make the breakage loud.
        XCTAssertEqual(FontScale.small.rawValue,    "small")
        XCTAssertEqual(FontScale.default.rawValue,  "default")
        XCTAssertEqual(FontScale.large.rawValue,    "large")
        XCTAssertEqual(FontScale.xLarge.rawValue,   "xLarge")
    }

    func test_fontScale_caseIterableCoversAllFour() {
        XCTAssertEqual(FontScale.allCases.count, 4)
    }

    // MARK: - NotchThemeID

    func test_notchThemeID_allSixCasesDecodeFromRawValues() throws {
        for id in NotchThemeID.allCases {
            let json = "\"\(id.rawValue)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(NotchThemeID.self, from: json)
            XCTAssertEqual(decoded, id)
        }
    }

    func test_notchThemeID_caseIterableHasSix() {
        XCTAssertEqual(NotchThemeID.allCases.count, 6)
    }

    // MARK: - HardwareNotchMode

    func test_hardwareNotchMode_bothCasesDecode() throws {
        let auto = try JSONDecoder().decode(HardwareNotchMode.self, from: "\"auto\"".data(using: .utf8)!)
        let virt = try JSONDecoder().decode(HardwareNotchMode.self, from: "\"forceVirtual\"".data(using: .utf8)!)
        XCTAssertEqual(auto, .auto)
        XCTAssertEqual(virt, .forceVirtual)
    }
}
```

**NOTE on `test_codable_decodingMissingFieldsFailsCleanly`:** If the
team prefers the opposite policy (Codable defaults-fill for missing
fields), flip this test AND update the struct to use a custom
`init(from:)` that provides defaults. The spec is silent on this
trade-off; the test as written enforces the strict policy. Adjust
to match team preference if needed before merging.

- [ ] **Step 2: Add the test file to the `ClaudeIslandTests` target**

In Xcode: right-click `ClaudeIslandTests/` → "Add Files to
ClaudeIsland…" → select `NotchCustomizationTests.swift` → ensure
**`ClaudeIslandTests`** target is checked (NOT `ClaudeIsland`).

- [ ] **Step 3: Run the tests and verify all pass**

```bash
xcodebuild test \
  -scheme ClaudeIsland \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ClaudeIslandTests/NotchCustomizationTests \
  2>&1 | tail -20
```

Expected: `Test Suite 'NotchCustomizationTests' passed` with all
nine tests green. If
`test_codable_decodingMissingFieldsFailsCleanly` fails, the
Codable default policy needs to be decided explicitly (see note in
step 1).

- [ ] **Step 4: Commit**

```bash
git add ClaudeIslandTests/NotchCustomizationTests.swift \
        ClaudeIsland.xcodeproj/project.pbxproj
git commit -m "test(notch): unit tests for NotchCustomization value type

Covers defaults, Codable roundtrip, FontScale mapping + raw-value
stability, NotchThemeID decoding, HardwareNotchMode cases."
```

---

### Task 1.4: Implement `NotchCustomizationStore` (init, load, save, migration)

**Files:**
- Create: `ClaudeIsland/Services/State/NotchCustomizationStore.swift`
- Xcode project: add to `ClaudeIsland` target

- [ ] **Step 1: Create the store with persistence-only behavior (no edit mode yet)**

```swift
//
//  NotchCustomizationStore.swift
//  ClaudeIsland
//
//  Central ObservableObject that holds the user's NotchCustomization
//  and persists it atomically under the UserDefaults key
//  `notchCustomization.v1`. Also handles a one-shot legacy migration
//  from older @AppStorage keys like `usePixelCat`.
//
//  Live-edit-mode state is layered on top in Task 1.5 (next task).
//  Keeping persistence and edit-mode state in separate commits makes
//  each diff reviewable on its own.
//

import Combine
import Foundation
import OSLog
import SwiftUI

@MainActor
final class NotchCustomizationStore: ObservableObject {
    static let shared = NotchCustomizationStore()

    private static let log = Logger(subsystem: "com.codeisland.app", category: "notchStore")
    private let defaultsKey = "notchCustomization.v1"

    @Published private(set) var customization: NotchCustomization

    private init() {
        if let loaded = Self.loadFromDefaults() {
            self.customization = loaded
            return
        }
        // No v1 key yet — one-shot migration from legacy keys.
        self.customization = Self.readLegacyOrDefault()
        if self.saveAndVerify() {
            Self.removeLegacyKeys()
        } else {
            Self.log.error("Initial v1 write failed; legacy keys retained for retry on next launch")
        }
    }

    // MARK: - Mutation

    /// All mutations funnel through here so the save call happens
    /// exactly once per user action.
    func update(_ mutation: (inout NotchCustomization) -> Void) {
        mutation(&customization)
        save()
    }

    // MARK: - Persistence

    @discardableResult
    private func save() -> Bool {
        do {
            let data = try JSONEncoder().encode(customization)
            UserDefaults.standard.set(data, forKey: defaultsKey)
            return true
        } catch {
            Self.log.error("save failed: \(error, privacy: .public)")
            return false
        }
    }

    /// Save and then read back to confirm the bytes landed. Used by
    /// migration so we only delete legacy keys after the new key is
    /// demonstrably on disk.
    private func saveAndVerify() -> Bool {
        guard save() else { return false }
        return Self.loadFromDefaults() != nil
    }

    private static func loadFromDefaults() -> NotchCustomization? {
        guard let data = UserDefaults.standard.data(forKey: "notchCustomization.v1") else {
            return nil
        }
        return try? JSONDecoder().decode(NotchCustomization.self, from: data)
    }

    // MARK: - Legacy migration

    /// Pull legacy @AppStorage values into a new NotchCustomization.
    /// Does NOT mutate UserDefaults — deletion is a separate step that
    /// only runs after the v1 key is successfully written.
    private static func readLegacyOrDefault() -> NotchCustomization {
        var c = NotchCustomization.default
        let d = UserDefaults.standard
        if d.object(forKey: "usePixelCat") != nil {
            c.showBuddy = d.bool(forKey: "usePixelCat")
        }
        // Future legacy keys go here, following the same pattern.
        return c
    }

    private static func removeLegacyKeys() {
        UserDefaults.standard.removeObject(forKey: "usePixelCat")
        // Future legacy keys go here.
    }
}
```

- [ ] **Step 2: Add the file to the Xcode target**

Create the group `ClaudeIsland/Services/State/` if it doesn't exist
yet. Add `NotchCustomizationStore.swift` to the `ClaudeIsland`
target.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -scheme ClaudeIsland -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ClaudeIsland/Services/State/NotchCustomizationStore.swift \
        ClaudeIsland.xcodeproj/project.pbxproj
git commit -m "feat(notch): add NotchCustomizationStore with legacy migration

ObservableObject singleton holding the user's NotchCustomization.
Persists to UserDefaults key notchCustomization.v1 via atomic
JSON-encoded blob. One-shot migration reads legacy usePixelCat
into showBuddy, then removes the legacy key ONLY after the new
key has been written and read-back verified — if migration fails
partway through, legacy keys stay intact and next launch retries.

Does not yet handle live edit mode state; that lands in the next
commit so the persistence-only diff is reviewable on its own.

See docs/superpowers/specs/2026-04-08-notch-customization-design.md
section 5.2."
```

---

### Task 1.5: Add live edit mode state machine to the store

**Files:**
- Modify: `ClaudeIsland/Services/State/NotchCustomizationStore.swift`

- [ ] **Step 1: Add `isEditing` and the draft snapshot plumbing**

Append to the class inside `NotchCustomizationStore.swift`:

```swift
// MARK: - Live edit lifecycle

/// Ephemeral, NOT persisted. Views observe this to switch into
/// live edit mode visuals.
@Published var isEditing: Bool = false

/// Snapshot of `customization` taken at `enterEditMode()`. On
/// `cancelEdit()` this is assigned back, rolling all in-session
/// changes in one atomic step. On `commitEdit()` this is cleared.
private var editDraftOrigin: NotchCustomization?

func enterEditMode() {
    editDraftOrigin = customization
    isEditing = true
}

func commitEdit() {
    editDraftOrigin = nil
    isEditing = false
    save()
}

func cancelEdit() {
    if let origin = editDraftOrigin {
        customization = origin
        save()
    }
    editDraftOrigin = nil
    isEditing = false
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme ClaudeIsland -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ClaudeIsland/Services/State/NotchCustomizationStore.swift
git commit -m "feat(notch): add live edit state machine to store

Adds isEditing @Published flag plus enterEditMode / commitEdit /
cancelEdit lifecycle methods. Cancel rolls back via an in-memory
snapshot taken at enter-time — no undo/redo history, just a
single commit-or-revert pair.

See docs/superpowers/specs/2026-04-08-notch-customization-design.md
section 5.2."
```

---

### Task 1.6: Write unit tests for `NotchCustomizationStore`

**Files:**
- Create: `ClaudeIslandTests/NotchCustomizationStoreTests.swift`

- [ ] **Step 1: Write failing tests covering init, migration, update, edit lifecycle**

```swift
//
//  NotchCustomizationStoreTests.swift
//  ClaudeIslandTests
//

import XCTest
@testable import ClaudeIsland

/// These tests manipulate UserDefaults.standard, so they must each
/// clean up their own keys to avoid bleeding into each other. We
/// cannot just use a suite-name-based UserDefaults because
/// NotchCustomizationStore.shared uses .standard explicitly — that's
/// fine for production and testable as long as we're careful.
@MainActor
final class NotchCustomizationStoreTests: XCTestCase {

    private let v1Key = "notchCustomization.v1"
    private let legacyBuddyKey = "usePixelCat"

    override func setUp() async throws {
        UserDefaults.standard.removeObject(forKey: v1Key)
        UserDefaults.standard.removeObject(forKey: legacyBuddyKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: v1Key)
        UserDefaults.standard.removeObject(forKey: legacyBuddyKey)
    }

    // MARK: - Helpers
    //
    // Because NotchCustomizationStore is a singleton, each test case
    // that wants a "fresh" store must use the private initializer
    // reflection or accept that it shares state with the app. To keep
    // the tests deterministic we use reflection via a test-only entry
    // point. If that reflection is too fragile, consider refactoring
    // the store to accept an injected UserDefaults at init time.

    // Creates a store by bypassing the singleton via `newInstanceForTests()`
    // (to be added as a test-only extension — see note below).
    private func makeStore() -> NotchCustomizationStore {
        return NotchCustomizationStore.newInstanceForTests()
    }

    // MARK: - Init / load

    func test_init_withNoKeys_returnsDefault() {
        let store = makeStore()
        XCTAssertEqual(store.customization, .default)
    }

    func test_init_withExistingV1Key_loadsIt() throws {
        var persisted = NotchCustomization.default
        persisted.theme = .cyber
        persisted.maxWidth = 520
        let data = try JSONEncoder().encode(persisted)
        UserDefaults.standard.set(data, forKey: v1Key)

        let store = makeStore()
        XCTAssertEqual(store.customization.theme, .cyber)
        XCTAssertEqual(store.customization.maxWidth, 520)
    }

    // MARK: - Migration

    func test_init_migratesLegacyUsePixelCatFalse() {
        UserDefaults.standard.set(false, forKey: legacyBuddyKey)

        let store = makeStore()
        XCTAssertFalse(store.customization.showBuddy)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: v1Key),
                        "v1 key should be written after migration")
        XCTAssertNil(UserDefaults.standard.object(forKey: legacyBuddyKey),
                     "legacy key should be removed after successful migration")
    }

    func test_init_migratesLegacyUsePixelCatTrue() {
        UserDefaults.standard.set(true, forKey: legacyBuddyKey)

        let store = makeStore()
        XCTAssertTrue(store.customization.showBuddy)
    }

    // MARK: - update closure

    func test_update_mutatesAndPersists() throws {
        let store = makeStore()
        store.update { $0.theme = .paper }

        XCTAssertEqual(store.customization.theme, .paper)

        // Roundtrip through UserDefaults
        let data = try XCTUnwrap(UserDefaults.standard.data(forKey: v1Key))
        let decoded = try JSONDecoder().decode(NotchCustomization.self, from: data)
        XCTAssertEqual(decoded.theme, .paper)
    }

    // MARK: - Edit lifecycle

    func test_enterEditMode_setsIsEditing() {
        let store = makeStore()
        XCTAssertFalse(store.isEditing)
        store.enterEditMode()
        XCTAssertTrue(store.isEditing)
    }

    func test_cancelEdit_rollsBackToSnapshot() {
        let store = makeStore()
        store.update { $0.maxWidth = 400 }
        store.enterEditMode()
        store.update { $0.maxWidth = 600 }
        XCTAssertEqual(store.customization.maxWidth, 600)
        store.cancelEdit()
        XCTAssertEqual(store.customization.maxWidth, 400)
        XCTAssertFalse(store.isEditing)
    }

    func test_commitEdit_keepsChanges() {
        let store = makeStore()
        store.update { $0.maxWidth = 400 }
        store.enterEditMode()
        store.update { $0.maxWidth = 600 }
        store.commitEdit()
        XCTAssertEqual(store.customization.maxWidth, 600)
        XCTAssertFalse(store.isEditing)
    }

    func test_editLifecycle_persistsCommittedChangesAcrossSimulatedReload() throws {
        let store1 = makeStore()
        store1.enterEditMode()
        store1.update { $0.theme = .mint }
        store1.commitEdit()

        let store2 = makeStore()
        XCTAssertEqual(store2.customization.theme, .mint)
    }
}
```

- [ ] **Step 2: Add the `newInstanceForTests()` test hook**

The private `init` of `NotchCustomizationStore` is intentionally
inaccessible. Expose it for tests via a test-only extension. Create
this in the test file (same file as the tests) so it lives in the
test target only:

```swift
// Inside NotchCustomizationStoreTests.swift, at file scope:
extension NotchCustomizationStore {
    /// Test-only factory that bypasses the singleton so each test case
    /// can observe a "fresh" instance. Declared here in the test file
    /// so the production target stays clean.
    fileprivate static func newInstanceForTests() -> NotchCustomizationStore {
        // Use reflection / Mirror to invoke the private init. If that
        // proves too fragile, refactor the production init to be
        // `internal` instead of `private` and document why (tests).
        let initializer = unsafeBitCast(
            NotchCustomizationStore.self as AnyClass,
            to: NSObject.Type.self
        ).init
        return initializer() as! NotchCustomizationStore
    }
}
```

**NOTE:** If the reflection-based factory above is too fragile to
compile cleanly (it often is in Swift), the cleaner alternative is to
change `private init()` to `internal init()` in
`NotchCustomizationStore.swift` and add a `// Exposed for tests`
comment. Do this if the reflection approach fights you.

- [ ] **Step 3: Run tests**

```bash
xcodebuild test \
  -scheme ClaudeIsland \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:ClaudeIslandTests/NotchCustomizationStoreTests \
  2>&1 | tail -30
```

Expected: all nine test methods pass.

- [ ] **Step 4: Commit**

```bash
git add ClaudeIslandTests/NotchCustomizationStoreTests.swift \
        ClaudeIsland/Services/State/NotchCustomizationStore.swift \
        ClaudeIsland.xcodeproj/project.pbxproj
git commit -m "test(notch): unit tests for NotchCustomizationStore

Covers init with no keys (returns default), init loading existing
v1 blob, legacy usePixelCat migration (both true and false),
update closure persistence, edit lifecycle enter/commit/cancel
including cross-simulated-reload persistence of committed changes.

If newInstanceForTests reflection is flaky on your toolchain, the
drop-in alternative is to change the production init from private
to internal and document why."
```

---

### Task 1.7: Inject the store at the app scene root

**Files:**
- Modify: `ClaudeIsland/App/ClaudeIslandApp.swift`

- [ ] **Step 1: Read the existing app file**

```bash
sed -n '1,40p' ClaudeIsland/App/ClaudeIslandApp.swift
```

Take note of the `@main struct ClaudeIslandApp: App { ... }` body
and the `Settings { ... }` scene (or whatever scenes exist).

- [ ] **Step 2: Inject the store**

Add a `@StateObject` property and apply `.environmentObject(...)` at
every scene in the app body. Example (adapt to match the existing
scene structure):

```swift
@main
struct ClaudeIslandApp: App {
    @StateObject private var notchStore = NotchCustomizationStore.shared

    var body: some Scene {
        Settings {
            SystemSettingsView()
                .environmentObject(notchStore)
        }
        // Any other scenes — wrap each with the same environmentObject.
    }
}
```

**NOTE:** CodeIsland is an AppKit-hosted hybrid — the main window
(`NotchWindow`) is created imperatively in `WindowManager`/
`AppDelegate`, not via a SwiftUI scene. For the SwiftUI `NotchView`
rendered inside `NotchWindow` to see the store via
`@EnvironmentObject`, the `NSHostingView` that wraps `NotchView`
must ALSO inject the store. That injection lives in
`WindowManager.swift` (or wherever `NSHostingView(rootView:
NotchView())` is constructed). Example:

```swift
let hosting = NSHostingView(
    rootView: NotchView()
        .environmentObject(NotchCustomizationStore.shared)
)
```

Search for every existing `NSHostingView(rootView:` in the project
and add the `.environmentObject(NotchCustomizationStore.shared)` on
its root view. This is the only way the store reaches SwiftUI
content hosted in imperative AppKit windows.

```bash
grep -rn "NSHostingView(rootView:" ClaudeIsland/ 2>&1
```

Add the environmentObject to every matching call site.

- [ ] **Step 3: Build to verify injection is syntactically correct**

```bash
xcodebuild -scheme ClaudeIsland -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. Views don't yet read from the
store (we haven't touched them), so the app's runtime behavior is
unchanged.

- [ ] **Step 4: Launch the app manually and verify nothing regressed**

```bash
xcodebuild -scheme ClaudeIsland -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/ build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" 2>&1 | tail -3
open 'build/Build/Products/Debug/Code Island.app'
```

Observe: notch renders normally, no crash, no visible change. Quit
the app via the menu bar.

- [ ] **Step 5: Commit**

```bash
git add ClaudeIsland/App/ClaudeIslandApp.swift \
        ClaudeIsland/Core/WindowManager.swift \
        <any other files touched for NSHostingView injection>
git commit -m "feat(notch): inject NotchCustomizationStore at all scene roots

Makes the store available to every SwiftUI view tree in the app,
including the NSHostingView that wraps NotchView inside the
imperatively-created NotchWindow. No view reads from the store
yet — that lands in subsequent chunks — so this change is purely
plumbing.

See docs/superpowers/specs/2026-04-08-notch-customization-design.md
section 5.4."
```

---

## End of Chunk 1

At this point:
- `Color(hex:)` helper lives in its own file, still used everywhere it was before.
- `NotchCustomization` struct + enums are defined and unit-tested.
- `NotchCustomizationStore` is a working singleton: loads, saves, migrates from `usePixelCat`, handles enter/commit/cancel edit lifecycle, all behind unit tests.
- The store is injected at every SwiftUI entry point in the app.
- No user-visible change yet. App still looks and behaves identically to `main`.

**Chunk 1 is self-contained and reviewable independently.** The implementer can merge it as a precursor PR if desired, then land subsequent chunks on top.

Next chunk (to be written after Chunk 1 passes plan review) handles the theme system, palette modifiers, font scaling, and asset catalog colors.

---

**NOTE (2026-04-09):** At the user's explicit request, the
chunk-by-chunk plan review loop was skipped for chunks 2-6.
Implementation was delegated to a single dedicated subagent using
the committed spec at
`docs/superpowers/specs/2026-04-08-notch-customization-design.md`
as the authoritative source. Chunk 1 above remains a worked example
of the plan decomposition pattern; chunks 2-6 were never written in
this file because the spec itself is detailed enough to drive the
implementation directly.
