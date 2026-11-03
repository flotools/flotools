# AGENTS.md

Instructions for coding agents working on the `swift` branch of Flo Tools. Read this file first, then `.pi/HANDOFF.md` if it exists.

## What this project is

Flo Tools makes Pro Tools usable with the VoiceOver screen reader. The shipped version is a Keyboard Maestro (KM) macro library on the `development` branch. This `swift` branch is an orphan branch with a native rewrite: a Swift Package that builds a menu bar app (no Dock icon) which drives Pro Tools through the macOS Accessibility API. `PORTING.md` explains the KM export and how KM and JXA concepts map to Swift.

## Where state lives

- `.pi/HANDOFF.md` is the work journal. It is not tracked by git (`.pi/` is in `.git/info/exclude`). Part 1 is the current state, the porting tracker and the exact next step; Part 2 is a dated `J-n` journal. Read Part 1 before doing anything. After every plan, code change, commit, live test or decision, append a journal entry and revise Part 1. Never rewrite old entries; add a correction entry instead. Keep observed results separate from inferences.
- `reference/macros/INDEX.md` is the frozen record of how each KM macro was ported (the "Ported" column): ported, absorbed by shared code, dropped or excluded.
- `plan.md` at the repository root is the agreed architecture and the decisions behind it. Code changes should match it; if the design changes, update `plan.md` in the same commit.
- `.pi/jobs/` holds jobs sent to other agents with `lmg ask`, one folder per job, with `task.md` and `responseN.md`.

## Rules that must not change

- Flo Tools for Keyboard Maestro is retired (legacy, no more support); all development happens here, and the Swift code is the source of truth. The KM export is a frozen porting reference.
- Commands keep their hotkeys and windows unless a change is decided on purpose; record it in plan.md section 9. `KeymapTests` pins every binding and the routing of shared keys in `Tests/Baselines/`; regenerate them with `FLO_WRITE_BASELINES=1 swift test --filter KeymapTests` and read the diff.
- Flo Mouse is not part of this app; it moves to a separate project. Do not port the Flo Mouse group or Toggle Flo Mouse.
- VoiceOver speech (`output`) and reading the VoiceOver cursor stay on Apple events to VoiceOver, sent directly from Swift without AppleScript source (VoiceOver does not speak accessibility announcements from a background app). Everything that touches Pro Tools uses the Accessibility API, not System Events.
- Spoken text should match the JXA version unless there is a stated reason to change it. Unit tests pin the text.
- Support the oldest macOS that does not cost current capabilities (currently macOS 13, `Package.swift` and `Resources/Info.plist`). Swift 6 language mode, strict concurrency.
- Do not edit `development` or anything outside this repository's `swift` branch.
- Updates will use Sparkle later. Do not port the KM update scripts: "Check for Update" (status menu) is dropped, and so is the update part of "Check for Automatic Update" (hardware profile, serial-number model lookup, sending specs to update.flotools.org). Keep that macro's other duties on Pro Tools launch: warn when VoiceOver cannot be controlled by AppleScript, reset per-session state ("Cleanup Variables"), reload preferences ("Refresh Preference"), and turn the Inspector on or off from the "starts with Flo Tools inspector" preference.

## Layout

- `Sources/FloSystem/`: generic macOS infrastructure (Accessibility, VoiceOver, hotkeys and synthetic keys, synthetic mouse moves and clicks, Flo Tools' own windows (the chooser and the text window), the front window observer (AX notifications for the focused window title), workspace events (apps launching and quitting, VoiceOver on and off), sounds, the system voice for the one warning VoiceOver cannot speak, the `Log`, and `FloError`, the one error model). `KeyNames.swift` is the one key-name table. Knows nothing about Pro Tools or commands.
- `Sources/FloEngine/`: the command model and runtime (the engine also holds suspension reasons and `cancelAll()`). `Command.swift` is the command model: ID, name, scope, mode condition, triggers and action; `Scope.swift` holds the windows a command works in (`Scope`), the app mode (`Mode`, the Inspector on or off) and a command's mode condition; `CommandRun.swift` is what a command body gets; `Engine.swift` indexes the commands by key, routes hotkeys to them, tells single from double presses and runs commands through one serial queue; `DoublePressDecider.swift` is the pure double-press logic; `Watches.swift` holds watches that commands start and stop, such as the level meter monitor, outside the queue, and the shared poll interval and failure streak; `SpokenError.swift` is the one table of failure wording; `Context.swift` is the front app and window title that scopes are checked against, with the ordering rules for title reads (the observer that reports changes is in `FloSystem`); `Preferences.swift`. Depends on `FloSystem` and `FloProTools` (for `ProToolsWindowKind`, plan.md section 2).
- `Sources/FloProTools/`: Pro Tools knowledge: finding the app, its windows (Mix, Edit toolbar controls, plug-in and AudioSuite windows, fade dialogs), tracks and their states, settings, and waiting for Pro Tools to show a change. `ProToolsWindowKind.swift` classifies each front window title as exactly one kind. Depends on `FloSystem` only.
- `Sources/FloFeatures/`: the commands, one folder per feature (`Inspector/`, `Tracks/`, `Counters/`, `MIDIEvents/`, `Settings/`, `Shortcuts/`, `Fades/`, `PlugIns/`, `Presets/` (shared by plug-in and AudioSuite windows), `AudioSuite/`, `Windows/`, `ClipDrag/`, `Preferences/`), each file declaring its commands' IDs, names, scopes, mode conditions, triggers and actions. At the top: `FloFeatures.swift` (`FloFeatures.all` lists the commands), `SessionState.swift` (what commands remember about the session), `SpokenList.swift` (the JXA's way of speaking a list) and `Lifecycle.swift` (what happens on VoiceOver and Pro Tools launch and quit and on window changes, replacing the KM Global group).
- `Sources/FloTools/`: the app (status menu, permission prompts, the preferences panel, the diagnostic log header).
- `Tests/FloToolsTests/`: Swift Testing unit tests. `Tests/Baselines/` holds `Keymap.txt` and `Routing.txt`, the keymap baselines `KeymapTests` compares against. `CommandReferenceTests` generates `COMMANDS.md` at the root, the user's list of commands with their keys, windows and summaries, from the declarations.
- `reference/`: frozen Keyboard Maestro material: the export, `macros/` with `INDEX.md`, the key set preset, the KM README, and `Plug-In Views/`, the plug-in view files that ship with Flo Tools: `build-app.sh` puts them in the app, and the app copies them into `~/Library/Application Support/Flo Tools/Plug-In Views/` on first launch, without overwriting the user's files.
- `scripts/build-app.sh`: builds and signs `build/Flo Tools.app`, with the sounds and plug-in views in its Resources.
- `Resources/`: `Info.plist`, entitlements, and `Sounds/` with the feedback sounds (`Done.aiff`, `Progress.aiff`; for now copies of the macOS Tink and Pop), which `build-app.sh` copies into the app.

Dependencies point one way: `FloTools` -> `FloFeatures` -> `FloEngine` -> `FloProTools` -> `FloSystem`. Update this section when the layout changes.

## Commands

Run from the repository root.

- Build: `swift build`
- Test: `swift test`
- App bundle: `scripts/build-app.sh` (universal release build, signed with the first "Apple Development" identity, or `FLO_SIGN_IDENTITY`). Always sign with the same identity, because Accessibility and Automation permissions are tied to the signature.
- Relaunch: `pkill -x FloTools; scripts/build-app.sh && open "build/Flo Tools.app"`
- App log: turn on the diagnostic log from the menu bar menu ("Turn On Log") and read the newest file in `~/Library/Logs/Flo Tools/`. The unified log (`log show --last 1m --predicate 'subsystem == "com.chikim.FloTools"' --style compact`) has only warnings and errors.

## Adding or changing a command

1. For behavior that came from KM, read its file in `reference/macros/<group>/<macro>.md` for the original wording and steps.
2. Declare it in its feature folder in `Sources/FloFeatures/` with an ID, name, summary (one or two sentences for users, for `COMMANDS.md`), scope, mode condition and hotkeys (`.key("Ctrl+2")`). Share code with commands of the same pattern (send and insert slots, transport toggles, counters, track lists, fade dialogs and so on).
3. Add unit tests for pure logic: message text, value parsing, filters.
4. Regenerate the baselines and `COMMANDS.md` (`FLO_WRITE_BASELINES=1 swift test --filter "KeymapTests|CommandReferenceTests"`) and check that the diff shows only the intended bindings, routing and summaries.
5. Build, run tests, rebuild the app and test it live (below).
6. Update `.pi/HANDOFF.md` and commit, with a message that says what was tested live.

## Testing live in Pro Tools

- Pro Tools must be running with a session open. Keyboard Maestro Engine must not be running, or its Flo Tools macros take the same keys.
- Front window: System Events `value of attribute "AXFocusedWindow"` of the Pro Tools process. VoiceOver cursor: `tell application "VoiceOver" to return text under cursor of vo cursor`.
- `scripts/vo.sh` wraps VoiceOver's AppleScript dictionary: read the VoiceOver cursor, keyboard cursor and last phrase, move the VoiceOver cursor (`move right`, `seek "Tom1"`), act on the item, click, speak, open VoiceOver menus, and run any VoiceOver command by its lower-case English name (`run "move left"`; `commands` lists them). Run it without arguments for the full list. Move the VoiceOver cursor this way, not with Ctrl+Opt+arrows from System Events: those reach Flo Tools' Inspector keys, and the owner's VoiceOver modifier is Caps Lock.
- Press a hotkey: `osascript -e 'tell application "System Events" to key code 19 using control down'`. For a double press, send two key codes 0.05 s apart in one script.
- Check speech: `osascript -e 'tell application "VoiceOver" to return content of last phrase'`. Check which command ran in the diagnostic log (`<combo> pressed in <context> -> <command ID>`).
- Restore any session state a test changes (solo, mute, record arm, selection, open windows and menus), and record what was changed and restored in the journal.
- Key presses from System Events go through the same hotkey path as physical keys, but say so when a result was not checked with a physical keyboard.

## Working with other agents

The owner uses `lmg ask` to consult other agents (see the lmg-ask skill). Fable (`lmg ask claude read|edit FOLDER --model claude-fable-5-1`) is the advisor for major design decisions; it has a weekly cap, so use it sparingly. Codex (`lmg ask codex read|edit FOLDER`) is the colleague for second opinions and goes first for questions code can settle. Run `lmg usage` before each ask and note the reading in the journal. Edit jobs need a git worktree. Check each answer file exists and has real content before using it.

## Code quality standard

This summarizes the owner's optimize-codebase standard, adapted to Swift. The aim is a codebase that could be shown to students as an example of good design: each part has a clear job, and a reader can follow what happens without reading everything.

### Design

- Prefer simple, cohesive designs over clever or highly abstract ones. A shorter design is not automatically better, and a more abstract one is not either.
- Give every module, type and function one clear responsibility. A reader should be able to say what it owns, what it depends on, what depends on it, what contract it exposes, and why it lives where it does.
- Keep separate concerns apart: Pro Tools knowledge, command behavior, the engine (triggers, context, enable state), macOS infrastructure (Accessibility, VoiceOver, hotkeys, input events, sounds, dialogs, files) and the app UI. Split files when it clarifies ownership, not mechanically.
- Keep dependencies pointing one way: app -> features -> core and infrastructure. Infrastructure never knows about specific commands. No circular dependencies.
- Make dependencies explicit through initializers or parameters where that helps testing and clarity. Avoid hidden global state; when a shared instance is needed, say why. No dependency injection frameworks.
- Every abstraction must reduce duplication, coupling, ambiguity or testing difficulty for a current need. Do not add protocols with one implementation, factories, managers, generic helpers, plugin systems or extension points for hypothetical futures. Do not add wrappers that only forward calls or rename things.
- Prefer a direct design when it keeps the separation clean.

### One source of truth

- Each concept has one representation and one implementation: one model of a command, one of a hotkey, one of a window condition, one double-press mechanism, one way to find a track, one preferences reader and writer.
- KM UIDs appear only in `reference/`. App code uses `CommandID`, never KM UIDs or display names, to find a command.
- When several commands share a pattern (send and insert slots, transport toggles, counters, track lists, fade dialogs), implement the pattern once and parameterize it. Do not copy 20 near-identical macros.
- No duplicate constants, repeated parsing or repeated formatting rules.

### One current implementation

- Keep exactly one current implementation. Do not leave old code beside new code, fallbacks, compatibility aliases, deprecated parameters, migration code or version branches. Git history keeps the old code.
- Preferences live in UserDefaults (`com.chikim.FloTools`), owned by `PreferencesStore`. The KM `flotools.json` file is not read or migrated (decided 2026-11-02).
- Remove dead code, unused parameters, stale comments and unreachable branches as you find them.

### Interfaces and data flow

- Use narrow interfaces with explicit inputs and outputs, domain names, and domain types where they prevent mistakes. Make invalid use hard, without chasing theoretical type purity.
- Avoid boolean-heavy APIs and long lists of optional parameters; name the operation or model the choice instead.
- Keep data flow traceable: trigger -> context check -> command logic -> Accessibility, speech or input side effect -> spoken result. Do not convert the same data between several near-identical shapes.
- Validate at boundaries: command installation (duplicate ID, a key that ties with another command's in the same windows and mode), reference generation, preferences loading, Accessibility reads.

### Errors and logging

- Use one error model. Core code returns or throws meaningful errors (Pro Tools not running, window missing, element missing, timeout); it does not silently return nil when the caller needs to know why.
- Decide what the user hears in one place, not separately in each command. Failures are spoken (KM showed a notification instead), with the wording in one table in the engine. Cancellation is silent.
- No broad catch-and-ignore except at a deliberate boundary, and log it there.
- Log where the context is, once per failure. Do not log secrets or identifiers (see Diagnostic log for what is allowed).

### Diagnostic log

Users must be able to send the developer a log that shows where a command failed. All logging goes through one logger, `Log` in `FloSystem/Log.swift`; do not call `Logger` or `print` directly.

- The menu bar menu has one item whose title switches between "Turn On Log" and "Turn Off Log". Logging is off by default.
- "Turn On Log" starts a new log file in `~/Library/Logs/Flo Tools/` and the title becomes "Turn Off Log". The on state is remembered across launches, so a relaunch or crash while reproducing a problem keeps logging. The file is needed because an app can only read back its own unified log for the current process, so earlier runs would be lost.
- "Turn Off Log" stops logging, closes the file, and reveals one file in Finder, selected, that the user can send as is. Use the macOS 13 `NSWorkspace.activateFileViewerSelecting`.
- That file starts with a header: app version and build, macOS version, Pro Tools version, whether VoiceOver is running, permission status, preferences, suspension, and whether the Inspector is on. Then the log entries. If Flo Tools crash reports from `~/Library/Logs/DiagnosticReports` were written while logging was on, append them at the end, with the values that identify the Mac (`crashReporterKey`, `deviceIdentifierForVendor`, `bootSessionUUID`) redacted. Nothing is uploaded automatically.
- While logging is on, write every entry at full detail, except debug entries inside a watch's polls and the front window poll (`Log.skipsDebug`), which at ten polls a second would fill the cap in minutes; their changes, speech and failures are still logged. Cap the file at about 20 MB by dropping the oldest entries, and log that entries were dropped. While logging is off, write nothing to a file; only warnings and errors go to the unified log (subsystem `com.chikim.FloTools`, one category per area).
- One line per entry: timestamp with milliseconds, level, category, invocation ID, message. Every command run gets an invocation ID that appears on every line it causes, including the tasks it starts, so one run can be followed from start to end.
- Trace each run: trigger (key, gesture, or event) and routing decision (context, chosen command ID and name, or why it passed through); each Accessibility step with its selector path, result, `AXError` and duration; speech requests and VoiceOver errors; the final result, error or cancellation with total duration.
- When a required element is missing, log the bounded subtree where the lookup stopped (role, title, description, index, a few levels deep). This shows what Pro Tools actually had in place of the expected element.
- Also log app start and stop, permission status changes, context changes, enable and suspension changes, preferences loads, and helper or event-tap failures.
- Track names, window titles, session names and spoken text may be logged; the user approved this (2026-11-02) because they help locate failures.
- Never log typed keys that no command matched, the clipboard, hardware identifiers, serial numbers or the user name. Write home paths as `~`.
- Logging must not block the caller: file writes happen on a serial background queue, and the event-tap callback only enqueues.

### Security

- Treat security as design: least privilege, safe defaults, explicit trust boundaries.
- Escape or pass as parameters anything put into AppleScript or shell commands; avoid shell commands where an API exists.
- Network access is limited to what the owner approved. Never send identifying hardware data.
- Keep hardened runtime and minimal entitlements; sign consistently.

### Efficiency

- Avoid repeated work that matters: re-walking the Accessibility tree per element, polling faster than needed, blocking the main thread on a busy Pro Tools.
- Choose fitting data structures (for example index hotkeys instead of scanning all commands). Do not micro-optimize at the cost of clarity, and explain real tradeoffs in `plan.md`.

### Swift style

- Clear, idiomatic Swift 6 with strict concurrency. State which actor owns mutable state.
- Structs and enums for data, small focused functions, value types and immutability where they help reasoning.
- No clever one-liners, force unwraps outside tests or truly impossible cases, or hidden side effects.
- Use consistent names across code, tests, logs and docs. Avoid vague names such as Manager, Helper, Utils, Handler or Data unless they are the real responsibility.

### Tests

- Test behavior at the right level: message text, value parsing, filters, hotkey resolution, enable state, double-press timing, the keymap and routing baselines, preferences reading and validation.
- Keep tests deterministic. Prefer designs where side effects can be supplied naturally over heavy mocking, and do not add abstractions only to mock them.
- Never weaken a test to make a change pass. If behavior changes on purpose, update the test and say why.
- Live Pro Tools checks complement unit tests; record them in the journal.

### Before finishing a change

Run the tests, read the whole diff, and check: no duplicate or obsolete path remains, names and error semantics are consistent, dependencies point the right way, new abstractions have a concrete reason, and the result is simpler to explain than before.

## Writing conventions

- Comments explain why, in short plain English. Do not restate the code or invent jargon.
- Markdown and other prose files: one paragraph per line, no soft wrapping, no bold or italics for emphasis.
