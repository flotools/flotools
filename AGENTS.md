# AGENTS.md

Instructions for coding agents working on the `swift` branch of Flo Tools. Read this file first, then `.pi/HANDOFF.md` if it exists.

## What this project is

Flo Tools makes Pro Tools usable with the VoiceOver screen reader. The shipped version is a Keyboard Maestro (KM) macro library on the `development` branch. This `swift` branch is an orphan branch with a native rewrite: a Swift Package that builds a menu bar app (no Dock icon) which drives Pro Tools through the macOS Accessibility API. `PORTING.md` explains the KM export and how KM and JXA concepts map to Swift.

## Where state lives

- `.pi/HANDOFF.md` is the work journal. It is not tracked by git (`.pi/` is in `.git/info/exclude`). Part 1 is the current state, the porting tracker and the exact next step; Part 2 is a dated `J-n` journal. Read Part 1 before doing anything. After every plan, code change, commit, live test or decision, append a journal entry and revise Part 1. Never rewrite old entries; add a correction entry instead. Keep observed results separate from inferences.
- `reference/macros/INDEX.md` is the tracked record of which macros are ported (the "Ported" column).
- `plan.md` at the repository root is the agreed architecture and refactor order. Code changes should match it; if the design changes, update `plan.md` in the same commit.
- `.pi/jobs/` holds jobs sent to other agents with `lmg ask`, one folder per job, with `task.md` and `responseN.md`.

## Rules that must not change

- Flo Tools for Keyboard Maestro is retired (legacy, no more support); all development happens here, and the Swift code is the source of truth. The KM export is a frozen porting reference.
- Ported macros keep their KM hotkeys, groups and window conditions, compatible with `reference/Flo Tools Key Set.ptpreset`, unless a change is decided on purpose. `KeyboardMaestroParityTests` enforces this; a deliberate change goes in its `changedOnPurpose` list with the reason.
- Flo Mouse is not part of this app; it moves to a separate project. Do not port the Flo Mouse group or Toggle Flo Mouse.
- VoiceOver speech (`output`) and reading the VoiceOver cursor stay on AppleScript to VoiceOver. Everything that touches Pro Tools uses the Accessibility API, not System Events.
- Spoken text should match the JXA version unless there is a stated reason to change it. Unit tests pin the text.
- Support the oldest macOS that does not cost current capabilities (currently macOS 13, `Package.swift` and `Resources/Info.plist`). Swift 6 language mode, strict concurrency.
- Do not edit `development` or anything outside this repository's `swift` branch.
- Updates will use Sparkle later. Do not port the KM update scripts: "Check for Update" (status menu) is dropped, and so is the update part of "Check for Automatic Update" (hardware profile, serial-number model lookup, sending specs to update.flotools.org). Keep that macro's other duties on Pro Tools launch: warn when VoiceOver cannot be controlled by AppleScript, reset per-session state ("Cleanup Variables"), reload preferences ("Refresh Preference"), and turn the Inspector group on or off from the "starts with Flo Tools inspector" preference.

## Layout

- `Sources/FloSystem/`: generic macOS infrastructure (Accessibility, VoiceOver, hotkeys and synthetic keys, sounds, the `Log`, and `FloError`, the one error model). `KeyNames.swift` is the one key-name table. Knows nothing about Pro Tools or macros.
- `Sources/FloEngine/`: the macro model and runtime. `Macro.swift` is the macro and group model; `MacroRun.swift` is what a macro body gets; `Engine.swift` routes hotkeys to macros, tells single from double presses and runs macros through one serial queue; `DoublePressDecider.swift` is the pure double-press logic; `SpokenError.swift` is the one table of failure wording; `Context.swift` tracks the front app and window (moves to `FloSystem` as an observer in plan step 7); `Preferences.swift`. Depends on `FloSystem` only.
- `Sources/FloProTools/`: Pro Tools knowledge (windows, the track under the VoiceOver cursor). Depends on `FloSystem` only.
- `Sources/FloMacros/`: `Groups.swift` (the groups and their conditions) and the macros, one file per area, each declaring its ID, name, group, triggers and action. `FloMacros.all` lists them.
- `Sources/FloTools/`: the app (status menu, permission prompts).
- `Tests/FloToolsTests/`: Swift Testing unit tests.
- `tools/km_export.py`: regenerates `reference/macros/` from `reference/Flo Tools.kmmacros`, keeping the Ported column.
- `scripts/build-app.sh`: builds and signs `build/Flo Tools.app`.

Dependencies point one way: `FloTools` -> `FloMacros` -> `FloEngine`, `FloProTools` -> `FloSystem`. This layout changes further with the refactor in `plan.md`. Update this section when it does.

## Commands

Run from the repository root.

- Build: `swift build`
- Test: `swift test`
- App bundle: `scripts/build-app.sh` (universal release build, signed with the first "Apple Development" identity, or `FLO_SIGN_IDENTITY`). Always sign with the same identity, because Accessibility and Automation permissions are tied to the signature.
- Relaunch: `pkill -x FloTools; scripts/build-app.sh && open "build/Flo Tools.app"`
- Regenerate macro reference files: `.venv/bin/python -I tools/km_export.py` (`--check` to only compare).
- Test the generator: `.venv/bin/python -I -m unittest discover -s tools`.
- App log: turn on the diagnostic log from the menu bar menu ("Turn On Log") and read the newest file in `~/Library/Logs/Flo Tools/`. The unified log (`log show --last 1m --predicate 'subsystem == "com.chikim.FloTools"' --style compact`) has only warnings and errors.

## Porting a macro

1. Read its file in `reference/macros/<group>/<macro>.md`, including any macros it calls with ExecuteMacro.
2. Declare it in `Sources/FloMacros/` with an ID `<group>.<lowerCamelName>`, the KM name, group and hotkeys (`.key("Ctrl+2")`), and add its KM UID to `macroOrigins` in `KeyboardMaestroParityTests`. Implement it sharing code with macros of the same pattern (send and insert slots, transport toggles, counters, track lists, fade dialogs and so on).
3. Add unit tests for pure logic: message text, value parsing, filters.
4. Build, run tests, rebuild the app and test it live (below).
5. Mark it "yes" in the "Ported" column of `reference/macros/INDEX.md`, update the tracker in `.pi/HANDOFF.md`, and commit. Commit per group or per pattern, with a message that says what was tested live.

## Testing live in Pro Tools

- Pro Tools must be running with a session open. Keyboard Maestro Engine must not be running, or its Flo Tools macros take the same keys.
- Front window: System Events `value of attribute "AXFocusedWindow"` of the Pro Tools process. VoiceOver cursor: `tell application "VoiceOver" to return text under cursor of vo cursor`.
- Press a hotkey: `osascript -e 'tell application "System Events" to key code 19 using control down'`. For a double press, send two key codes 0.05 s apart in one script.
- Check speech: `osascript -e 'tell application "VoiceOver" to return content of last phrase'`. Check which macro ran in the diagnostic log (`<combo> pressed in <context> -> <macro ID>`).
- Restore any session state a test changes (solo, mute, record arm, selection, open windows and menus), and record what was changed and restored in the journal.
- Key presses from System Events go through the same hotkey path as physical keys, but say so when a result was not checked with a physical keyboard.

## Working with other agents

The owner uses `lmg ask` to consult other agents (see the lmg-ask skill). Fable (`lmg ask claude read|edit FOLDER --model claude-fable-5-1`) is the advisor for major design decisions; it has a weekly cap, so use it sparingly. Codex (`lmg ask codex read|edit FOLDER`) is the colleague for second opinions and goes first for questions code can settle. Run `lmg usage` before each ask and note the reading in the journal. Edit jobs need a git worktree. Check each answer file exists and has real content before using it.

## Code quality standard

This summarizes the owner's optimize-codebase standard, adapted to Swift. The aim is a codebase that could be shown to students as an example of good design: each part has a clear job, and a reader can follow what happens without reading everything.

### Design

- Prefer simple, cohesive designs over clever or highly abstract ones. A shorter design is not automatically better, and a more abstract one is not either.
- Give every module, type and function one clear responsibility. A reader should be able to say what it owns, what it depends on, what depends on it, what contract it exposes, and why it lives where it does.
- Keep separate concerns apart: Pro Tools knowledge, macro behavior, the engine (triggers, context, enable state), macOS infrastructure (Accessibility, VoiceOver, hotkeys, input events, sounds, dialogs, files) and the app UI. Split files when it clarifies ownership, not mechanically.
- Keep dependencies pointing one way: app -> macros -> core and infrastructure. Infrastructure never knows about specific macros. No circular dependencies.
- Make dependencies explicit through initializers or parameters where that helps testing and clarity. Avoid hidden global state; when a shared instance is needed, say why. No dependency injection frameworks.
- Every abstraction must reduce duplication, coupling, ambiguity or testing difficulty for a current need. Do not add protocols with one implementation, factories, managers, generic helpers, plugin systems or extension points for hypothetical futures. Do not add wrappers that only forward calls or rename things.
- Prefer a direct design when it keeps the separation clean.

### One source of truth

- Each concept has one representation and one implementation: one model of a macro, one of a hotkey, one of a window condition, one double-press mechanism, one way to find a track, one preferences reader and writer.
- KM UIDs appear only in `KeyboardMaestroParityTests`. App code uses `MacroID` and `MacroGroupID`, never KM UIDs or display names, to find a macro or group.
- When several macros share a pattern (send and insert slots, transport toggles, counters, track lists, fade dialogs), implement the pattern once and parameterize it. Do not copy 20 near-identical macros.
- No duplicate constants, repeated parsing or repeated formatting rules.

### One current implementation

- Keep exactly one current implementation. Do not leave old code beside new code, fallbacks, compatibility aliases, deprecated parameters, migration code or version branches. Git history keeps the old code.
- The one deliberate exception is the preferences file `~/Library/Application Support/Flo Tools/flotools.json`, whose format is shared with the KM version and is the current format.
- Remove dead code, unused parameters, stale comments and unreachable branches as you find them.

### Interfaces and data flow

- Use narrow interfaces with explicit inputs and outputs, domain names, and domain types where they prevent mistakes. Make invalid use hard, without chasing theoretical type purity.
- Avoid boolean-heavy APIs and long lists of optional parameters; name the operation or model the choice instead.
- Keep data flow traceable: trigger -> context check -> macro logic -> Accessibility, speech or input side effect -> spoken result. Do not convert the same data between several near-identical shapes.
- Validate at boundaries: macro installation (unknown group, duplicate ID), reference generation, preferences loading, Accessibility reads.

### Errors and logging

- Use one error model. Core code returns or throws meaningful errors (Pro Tools not running, window missing, element missing, timeout); it does not silently return nil when the caller needs to know why.
- Decide what the user hears in one place, not separately in each macro. Failures are spoken (KM showed a notification instead), with the wording in one table in the engine. Cancellation is silent.
- No broad catch-and-ignore except at a deliberate boundary, and log it there.
- Log where the context is, once per failure. Do not log secrets or identifiers (see Diagnostic log for what is allowed).

### Diagnostic log

Users must be able to send the developer a log that shows where a macro failed. All logging goes through one logger, `Log` in `FloSystem/Log.swift`; do not call `Logger` or `print` directly.

- The menu bar menu has one item whose title switches between "Turn On Log" and "Turn Off Log". Logging is off by default.
- "Turn On Log" starts a new log file in `~/Library/Logs/Flo Tools/` and the title becomes "Turn Off Log". The on state is remembered across launches, so a relaunch or crash while reproducing a problem keeps logging. The file is needed because an app can only read back its own unified log for the current process, so earlier runs would be lost.
- "Turn Off Log" stops logging, closes the file, and reveals one file in Finder, selected, that the user can send as is. Use the macOS 13 `NSWorkspace.activateFileViewerSelecting`.
- That file starts with a header: app version and build, macOS version, Pro Tools version, whether VoiceOver is running, permission status, preferences, and enabled and suspended groups. Then the log entries. If Flo Tools crash reports from `~/Library/Logs/DiagnosticReports` were written while logging was on, append them at the end, with the values that identify the Mac (`crashReporterKey`, `deviceIdentifierForVendor`, `bootSessionUUID`) redacted. Nothing is uploaded automatically.
- While logging is on, write every entry at full detail. Cap the file at about 20 MB by dropping the oldest entries, and log that entries were dropped. While logging is off, write nothing to a file; only warnings and errors go to the unified log (subsystem `com.chikim.FloTools`, one category per area).
- One line per entry: timestamp with milliseconds, level, category, invocation ID, message. Every macro run gets an invocation ID that appears on every line it causes, including nested calls, so one run can be followed from start to end.
- Trace each run: trigger (key, gesture, or event) and routing decision (context, chosen macro UID and name, or why it passed through); each Accessibility step with its selector path, result, `AXError` and duration; speech requests and VoiceOver errors; the final result, error or cancellation with total duration.
- When a required element is missing, log the bounded subtree where the lookup stopped (role, title, description, index, a few levels deep). This shows what Pro Tools actually had in place of the expected element.
- Also log app start and stop, permission status changes, context changes, enable and suspension changes, preferences loads, and helper or event-tap failures.
- Track names, window titles, session names and spoken text may be logged; the user approved this (2026-11-02) because they help locate failures.
- Never log typed keys that no macro matched, the clipboard, hardware identifiers, serial numbers or the user name. Write home paths as `~`.
- Logging must not block the caller: file writes happen on a serial background queue, and the event-tap callback only enqueues.

### Security

- Treat security as design: least privilege, safe defaults, explicit trust boundaries.
- Escape or pass as parameters anything put into AppleScript or shell commands; avoid shell commands where an API exists.
- Network access is limited to what the owner approved. Never send identifying hardware data.
- Keep hardened runtime and minimal entitlements; sign consistently.

### Efficiency

- Avoid repeated work that matters: re-walking the Accessibility tree per element, recompiling AppleScript, polling faster than needed, blocking the main thread on a busy Pro Tools.
- Choose fitting data structures (for example index hotkeys instead of scanning all macros). Do not micro-optimize at the cost of clarity, and explain real tradeoffs in `plan.md`.

### Swift style

- Clear, idiomatic Swift 6 with strict concurrency. State which actor owns mutable state.
- Structs and enums for data, small focused functions, value types and immutability where they help reasoning.
- No clever one-liners, force unwraps outside tests or truly impossible cases, or hidden side effects.
- Use consistent names across code, tests, logs and docs. Avoid vague names such as Manager, Helper, Utils, Handler or Data unless they are the real responsibility.

### Tests

- Test behavior at the right level: message text, value parsing, filters, hotkey resolution, enable state, double-press timing, parity with the KM export, preferences format.
- Keep tests deterministic. Prefer designs where side effects can be supplied naturally over heavy mocking, and do not add abstractions only to mock them.
- Never weaken a test to make a change pass. If behavior changes on purpose, update the test and say why.
- Live Pro Tools checks complement unit tests; record them in the journal.

### Before finishing a change

Run the tests, read the whole diff, and check: no duplicate or obsolete path remains, names and error semantics are consistent, dependencies point the right way, new abstractions have a concrete reason, and the result is simpler to explain than before.

## Writing conventions

- Comments explain why, in short plain English. Do not restate the code or invent jargon.
- Markdown and other prose files: one paragraph per line, no soft wrapping, no bold or italics for emphasis.
