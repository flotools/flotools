# Flo Tools Swift port: architecture and refactor plan

This is the agreed design for the native port. It merges two independent plans, from Fable (`.pi/jobs/plan-fable/response1.md`) and Codex (`.pi/jobs/plan-codex/response1.md`), with the owner's decisions recorded in `AGENTS.md`. Where the two plans disagreed, section 9 says which way was chosen and why. Read the two source plans for detail and reasoning not repeated here.

## 1. Goal and fixed rules

Refactor the two-macro proof into a structure the remaining 298 macros can be ported into, then port them group by group. The rules in `AGENTS.md` ("Rules that must not change") apply: identical hotkeys from the generated catalog, AppleScript only for VoiceOver, Accessibility for everything in Pro Tools, spoken text as in the JXA, macOS 13, Swift 6 strict concurrency, Sparkle for updates later.

Flo Mouse is out of scope; it moves to a separate project (owner decision, 2026-11-02). The generator excludes its group and Toggle Flo Mouse from the Swift catalog, which leaves 274 macros in 10 groups. Enable/Disable Flo Tools must not touch Flo Mouse when ported.

The two ported macros (Speak/Open Send B, Speak Soloed Tracks/Unsolo All Tracks) are re-tested live after every step that touches their path.

## 2. Problems in the current code

Both plans found these independently, by reading the code. They are not yet reproduced live.

- Pro Tools knowledge is split between `FloToolsCore/ProTools.swift` and `FloMacros` (`Tracks`). Generic code knows `"Mix:"` and track suffixes.
- Hidden singletons (`MacroEngine.start()` reaches `HotKeyCenter.shared`, `ContextMonitor.shared`; `DoublePress.shared`), so dispatch cannot be tested.
- Double press is coded in each macro with string keys and its own Tink. Expired entries are not cancelled, so an old callback can clear a newer entry, and a delayed single can run after its macro is disabled.
- `MacroAction` is synchronous on the main actor. All AX and AppleScript calls run on the main actor, so a busy Pro Tools freezes hotkeys and the menu. Monitors (meters, plug-in, event start) cannot be written in this shape.
- No error model: AX queries return nil or empty, failed presses are ignored, `unsoloAll` always says "unsoloed all tracks."
- `HotKeyCenter.passThrough` unregisters, posts, sleeps 100 ms and re-registers unconditionally. A key can be lost during a context change, and an obsolete registration can be restored.
- `ContextMonitor` polls every second forever, refreshes synchronously inside the hotkey handler, discards its observer token, and records the PID before observer creation succeeds (so it never retries after permission is granted).
- `otherTriggers` is a list of strings; group identity is by name; macros are registered by raw UID strings.
- `VoiceOver.say` interpolates text into AppleScript source, recompiles every call, swallows errors and logs spoken text as public.
- Preferences: hand-rolled JSON, non-atomic writes, a malformed file silently becomes defaults, and only the timeout is applied.
- Two Python tools repeat plist walking and the key table (also repeated in Swift). Regenerating `INDEX.md` erases the "Ported" column.

## 3. Targets and dependency direction

| Target | Owns | Depends on |
|---|---|---|
| `FloSystem` | Generic macOS infrastructure: `AXElement` and `AccessibilityActor`, `VoiceOver`, `HotKeyCenter`, `KeyCombo`, `Keyboard`, `Mouse`, `Clipboard`, `Sound`, `Dialogs`, `FrontWindowObserver`, `ApplicationObserver`, permissions, the logger (`Log`) | Apple frameworks |
| `FloEngine` | Macro model and runtime: generated catalog, `MacroID`, `MacroGroupID`, `MacroRecord`, `MacroTrigger`, `FrontContext`, `MacroGroup`, `Macro`, `MacroRun`, `MacroEngine`, `DoublePressDecider`, `Monitors`, preferences | `FloSystem` |
| `FloProTools` | Pro Tools knowledge: `ProToolsApp`, `MixWindow`, `EditWindow`, `TrackStrip`, `PlugInWindow`, `AudioSuiteWindow`, `FadeDialog`, `ProToolsMenuBar`, counter and value parsing | `FloSystem` |
| `FloMacros` | Ported macros, one folder per KM group or pattern, their state, the preferences window | `FloEngine`, `FloProTools` |
| `FloTools` | App: `AppDelegate`, status menu, permission prompts, wiring | `FloEngine`, `FloMacros` |

`FloEngine` never imports `FloProTools`; nothing below `FloMacros` knows a macro by name. No protocols for mocking; dependencies are concrete instances passed through initializers or captured by closures. All `.shared` singletons go.

## 4. Macro model

- The generator emits `MacroID` constants (camelCase of the KM name, group-prefixed on collision), `MacroGroupID` with group UIDs, `Catalog.groups`, `Catalog.macros` with typed triggers, the key-name table and a SHA-256 of the export. Swift code never contains a UID literal.
- `MacroTrigger`: `.hotKey(KeyCombo, on: .press | .release)`, `.focusedWindow(...)` keeping KM's three kinds distinct (`FocussedWindowChanges`, `FocussedWindowTitleChanges`, `FocussedWindowsTitleChanged`), `.application(.launched | .quit, bundleID:)`, `.statusMenu`. The generator fails on any unknown trigger, fire type, condition or targeting.
- `Macro(id, body)` or `Macro(id, single:, double:)`. `MacroBody = @MainActor @Sendable (MacroRun) async throws -> Void`. `MacroRun` carries the record, the trigger, the front context, an invocation ID and ancestry (for logging and nested-call cycle checks) and the engine.
- The engine owns double press, keyed by `MacroID`, through a pure `DoublePressDecider` tested with explicit instants. It plays Tink before `double`, as almost every JXA macro does; Speak/Toggle Mute calls `double()` first and then Tink, so a macro can choose Tink after. Repeat events are not taps. Pending singles get a generation number and are cancelled on disable, context invalidation, preferences change and stop.
- `MacroEngine.install(_:)` validates that every ID exists in the catalog and none is installed twice. Unported macros are not installed, so their keys stay free.
- Enable state separates group enabled, group active (enabled and applies to the context), macro enabled, and automatic suspension reasons (VoiceOver not running, Keyboard Shortcuts window open). Removing one suspension reason does not clear another or override a user choice. Explicit user enable and disable choices persist in `UserDefaults` keyed by UID; suspensions do not.
- `engine.run(_:)` is the one path for nested ExecuteMacro calls, status menu items and palettes. Nested calls run inside the parent, bypass trigger activation filtering, propagate errors and cancellation, and reject cycles.
- Mutating Pro Tools operations run through one foreground queue so two macros cannot interleave across `await`. `Monitors` holds one tracked task per monitor; `engine.cancelAll()` implements Cancel Macros.
- Macro families share one parameterized implementation (send slots, insert slots, fade dialogs, counters, track lists, plug-in navigation). Sends and inserts keep separate layout rules because their AX layouts differ.

## 5. System layer

- Accessibility: `AXElement` isolated to a global `AccessibilityActor`, so a busy Pro Tools blocks that actor and not the main actor. Typed attributes, role-filtered child lists and filters that match the JXA vocabulary (`buttons[2]`, `groups.byName`, `whose`), with batched attribute reads. Immediate-child lookups never fall back to a whole-tree search. Messaging timeout 1 s global and on the Pro Tools application element; tune from live measurement.
- Errors: queries return optionals for ordinary absence. `FloProTools` turns a missing required element into a thrown `FloError` with `required(_:)`. AX actions (`press`, `perform`, `set`) throw with the `AXError`. A failed read is never treated as "off".
- One error model: `FloSystem` defines `FloError` (cases for AX failures with the `AXError`, VoiceOver failures, timeouts, cancellation, and `notFound(what:)`). `ProToolsError` and the former `VoiceOverError` are not separate types; `FloProTools` throws `FloError` with Pro Tools-specific descriptions (window missing, no track under cursor). `MacroError` is dropped. This keeps `FloEngine` free of a `FloProTools` import.
- What the user hears on failure is decided in one function in the engine (`SpokenError`), which switches on `FloError`. Cancellation is silent. A failure to speak an error is logged, never retried by speaking.
- VoiceOver: three scripts compiled once with handlers (`say`, `cursorText`, `lastPhrase`), called with the text as an Apple event parameter. `escape` is removed. Errors throw `FloError`. Runs on the main actor because `NSAppleScript` is main-thread-only.
- Hotkeys: Carbon `RegisterEventHotKey` stays, with context-dependent registration, press and release events, and the instance reached through `refcon`. Pass-through and simulated keystrokes use `CGEvent.postToPid` to the front app, with no unregister and re-register window. Every synthetic event carries a Flo Tools `eventSourceUserData` marker.
- Context: `FrontWindowObserver` and `ApplicationObserver` are instances with explicit `start()` and `stop()`. `FrontContext` adds PID and window identity so window changes and title changes are distinguishable. AX notifications drive refreshes; a slow poll runs only while no observer is attached; failed attachment is retried. Context is read off the main actor, never synchronously inside the hotkey callback.
- Logger: one `Log` used everywhere, as specified in `AGENTS.md` ("Diagnostic log"): "Turn On Log" and "Turn Off Log" menu item, file in `~/Library/Logs/Flo Tools/` revealed in Finder on turn-off, header with versions, permissions, preferences and group state, invocation IDs on every line, per-step AX trace and subtree dumps where a lookup fails.

## 6. Pro Tools layer

`FloProTools` is the one place where System Events paths become named things: `ProToolsApp.running()`, `mix()`, `edit()`, `plugIn()`, `audioSuite()`, `fadeDialog()`, `menuBar()`, `keystroke(_:)`; `MixWindow.trackStrips()`, `trackUnderVoiceOverCursor()` (the one place the VoiceOver cursor is joined to a strip), `hasActiveGroups()`; `TrackStrip` with name, kind, solo, mute, record arm, `send(_:)`, `insert(_:)`, volume, pan, meters, comments; `EditWindow` counters, grid, nudge; and so on. Reads return small value structs so the next step is a pure function.

Unsolo All Tracks is hardened as the model for multi-step mutations: validate the window and process, read eligible tracks (excluding master, safe, inactive), suspend groups and verify, process ordinary tracks before folders, revalidate each target before toggling, restore group state on completion, error or cancellation, and announce success only after full success. Partial completion is reported as such.

## 7. Preferences and state

- Path and JSON shape stay exactly as the KM version writes them (`"temporary inspector"`, `"starts with Flo Tools inspector"`, `"timeout"` as a string). `Codable` with explicit keys; a test pins the JSON text. The reader accepts a numeric timeout; the writer writes a string.
- Missing file means defaults. A malformed file is logged and not overwritten; the last valid preferences stay in effect. Saves are atomic.
- `PreferencesFile.apply(_:to:)` is the single home of KM's "Refresh Preference" (timeout, temporary Inspector). The menu item and the "Flo Tools Preferences" macro open the same AppKit panel (two checkboxes, timeout popup 200/300/400/500).
- Transient KM variables become typed state owned by the macro family that uses it, reset at the matching lifetime boundary (Pro Tools quit, window change).
- Plug-in view files keep their JSON-in-`.txt` format and location; filenames from window titles are sanitized to one path component.

## 8. Tooling, packaging, tests

- Merge `tools/gen_catalog.py` and `tools/extract_macros.py` into `tools/km_export.py` with `catalog` and `macros` subcommands, one plist loader and one key table. `catalog --check` fails on a diff. `macros` keeps the "Ported" column from the existing `INDEX.md` when regenerating, and confines deletion to `reference/macros/`. Add standard-library Python tests.
- The Swift key-name table is generated, not hand-written.
- A Swift test reads `reference/macros/INDEX.md` and fails if the "Ported" column does not match the installed macro list, so the column cannot drift from the code.
- `scripts/build-app.sh` fails a signed build when the signing identity is missing instead of falling back to ad hoc.
- Unit tests (deterministic, no sleeps): catalog integrity, routing and specificity, enable and suspension state, trigger matching, double-press decisions, runner (nesting, cycles, cancellation, partial failure), error-to-speech table, preferences JSON, and per-area text and parsing.
- Live tests in Pro Tools as in `AGENTS.md`, plus `scripts/live-test.sh` (press a key through System Events, print the last VoiceOver phrase and the log line). Plan-specific live checks: synthetic keys posted to a PID do not re-trigger hotkeys, AX timeout behavior with Pro Tools busy, temporary Inspector hold with a physical keyboard, fade dialog groups active on the first key press, monitors stop on title change and Pro Tools quit, permission granted later recovers without relaunch.

## 9. Disagreements and decisions

| Topic | Fable | Codex | Decision |
|---|---|---|---|
| Key input | Keep Carbon hotkeys, pass through with `postToPid` | Replace with one `CGEventTap` | Carbon with `postToPid`. It is the smaller change, keeps the working path, and needs no new permission. Carbon supports zero-modifier hotkeys and release events (Codex corrected its earlier claim). Step 6 verifies live, with Flo Tools in the background: each pass-through or simulated key, modified and unmodified, reaches the target once and invokes no macro; `/` and backtick pass through outside Mix/Edit; backtick hold, Inspector command, release; modifier change while held; switching away before release. The backtick registration stays alive for the whole hold, and the hold is tracked independently of routing and cleared on focus loss, disable and stop. The `eventSourceUserData` marker is for logs and taps only; Carbon hotkey events do not carry it. Switch to an event tap only if a check fails. |
| VoiceOver isolation | Compiled handlers on the main actor | Separate helper executable | Main actor. A helper adds a second signed executable and IPC for a risk not yet observed. Measure `say` and `cursorText` durations in the log; revisit if VoiceOver stalls the app. Step 5 includes a check with VoiceOver unresponsive, since a stalled `cursorText` also delays hotkey handling, including the temporary Inspector release. |
| AX threading | Global actor | Dedicated thread with its own run loop | Global actor. Simpler and enforced by the compiler. The messaging timeout bounds each AX call, not a whole traversal, so long jobs such as Unsolo All check for cancellation between operations. AX observers keep an explicit run-loop owner. |
| Targets | Four libraries, catalog in the engine | Three libraries, Foundation-only core, catalog in macros | Fable's four. The separate Pro Tools target is the main structural gain. |
| Generator | One script with subcommands | Python package with `-m` commands | One script; `python -I` does not put the script directory on `sys.path`, so a shared module needs extra machinery. Generated key names live next to `KeyCombo` in `FloSystem`, so `FloSystem` never reads the engine catalog. |
| "Ported" column | Keep hand-edited | Remove; the registry is the authority | Keep it, preserve it on regeneration, and check it against the registry in a Swift test. `dropped (...)` and `excluded (...)` are deliberate non-implementations, not mismatches. |
| Durable enable state | Not persisted | `UserDefaults` overrides by UID | Persist explicit user choices, as KM does. Temporary Inspector activation and automatic suspensions are never persisted, and the startup Inspector preference still applies. |
| Updates | URLSession check | Native manifest | Neither: Sparkle later (owner decision). |
| Logging of session text | Private | Private | Logged in the opt-in diagnostic log (owner decision). |

## 10. Implementation sequence

Each step ends with `swift build`, `swift test`, a journal entry and a commit. Steps marked live end with a live re-test of the two ported macros.

1. Generator and typed catalog: `tools/km_export.py`, `MacroID`, `MacroGroupID`, `MacroRecord`, typed `MacroTrigger`, generated key names, `--check`, Ported-column preservation, Python tests.
2. Target split as a pure move: `FloSystem`, `FloEngine`, `FloProTools`; split `Support.swift`; remove `FloToolsCore`. Add `Log` with the file log and menu item. Update the `AGENTS.md` layout.
3. Engine: `Macro`, `MacroRun`, `FloError`, `SpokenError`, `DoublePressDecider`, `Monitors`, foreground queue, `install` validation, nested `run`, combo index, injected instances, no singletons: `HotKeyCenter`, `ContextMonitor` and observers become instances with explicit lifetimes here, while their input mechanics change in steps 6 and 7. Port both macros to the new shape. Live.
4. Accessibility: `AccessibilityActor`, typed values, role lists and filters, throwing actions, subtree dumps for the log. Live.
5. VoiceOver: compiled handlers, parameters, `FloError` on failure, durations logged. Live, including a track name containing a quote and an unresponsive VoiceOver.
6. Hotkeys and input: instance `HotKeyCenter`, `postToPid` pass-through, synthetic-event marker, `Keyboard.isDown`, `MacroRun.passThrough()`, and a minimal Toggle Temporary Inspector with its startup preference so hold and release are tested on the real macro. Live: the checks listed under "Key input" in section 9.
7. Context and triggers: observers with start and stop, window identity, three focused-window kinds, launch and quit, status menu, enabled versus active, suspension reasons, persisted user choices. Live.
8. Pro Tools layer and hardened Unsolo All; delete `ProTools.swift` statics and `Tracks`. Live.
9. Preferences: Codable model, atomic save, `apply`, preferences panel and macro. Live.
10. Port by pattern, adding `Dialogs`, `Mouse` and `Clipboard` with the first macro that needs each: fade dialogs, Selected Tab, Inspector (sends, inserts, solo, mute, arm, input, name, volume, pan, comments, meters), transport and menu toggles, counters and grid/nudge, track lists and playlists, Global enable/disable and window-triggered macros (including the launch duties of Check for Automatic Update), Plug-in and Audio Suite, event monitors.

## 11. Not done on purpose

No KM action interpreter, no plugin system for macros, no protocols for mocking AX or VoiceOver, no compatibility path for the old `register(uid)` API, no shell commands at runtime, no telemetry.
