## What this project is

Flo Tools makes Pro Tools more efficient to use with the VoiceOver screen reader by driving Pro Tools through the macOS Accessibility API. It is a native Swift rewrite of a Keyboard Maestro (KM) macro library on the `development` branch.

## Where state lives

- `.pi/HANDOFF.md` is the work journal (untracked). Read Part 1 (current state, tracker, next step) before doing anything. After every plan, code change, commit, live test or decision, append a dated `J-n` entry to Part 2 and revise Part 1. Never rewrite old entries; add a correction. Keep observed results separate from inferences.
- `plan.md` is the agreed architecture and the reasons behind it. Code must match it; if the design changes, update it in the same commit.
- `PORTING.md` maps KM and JXA concepts to Swift. `reference/macros/INDEX.md` is the frozen record of how each KM macro was ported.
- `.pi/jobs/` holds `lmg ask` jobs, one folder each with `task.md` and `responseN.md`.
- `.pi/release-notes/<version>.md` is each release's user-facing notes, used for both the GitHub release and the appcast item; edit it first, then both. The appcast is `appcast.xml` on `gh-pages`, checked out at `../flotools-gh-pages`. Release steps are in plan.md section 6.

## Rules that must not change

- The KM version is retired. The Swift code is the source of truth; the KM export is a frozen reference.
- Commands keep their hotkeys and windows unless changed on purpose and recorded in plan.md section 9. `KeymapTests` pins them in `Tests/Baselines/`.
- Do not port Flo Mouse or Toggle Flo Mouse; it becomes a separate project.
- VoiceOver speech and VoiceOver cursor reads use Apple events sent directly from Swift (no AppleScript source). Everything touching Pro Tools uses the Accessibility API, not System Events.
- Spoken text matches the JXA unless there is a stated reason. Unit tests pin it.
- Target macOS 13 (`Package.swift`, `Resources/Info.plist`), Swift 6 language mode, strict concurrency.
- Edit only this repository's `swift` branch. Exceptions: a release updates `appcast.xml` on `gh-pages`, and testing installs the app in `/Applications`.
- Updates use Sparkle (`Sources/FloTools/Updater.swift`). Do not port the KM update scripts. Of "Check for Automatic Update", keep only the Pro Tools launch duties: warn when VoiceOver cannot be controlled by AppleScript, reset session state, reload preferences, and set the Inspector from the "starts with Flo Tools inspector" preference.

## Layout

Targets, with dependencies pointing one way (`FloTools` -> `FloFeatures` -> `FloEngine` -> `FloProTools` -> `FloSystem`). plan.md section 2 lists what each owns.

- `Sources/FloSystem/`: generic macOS infrastructure (Accessibility, VoiceOver, hotkeys, synthetic input, own windows, window observer, workspace events, sounds, `Log`, `FloError`). Knows nothing about Pro Tools or commands.
- `Sources/FloProTools/`: Pro Tools knowledge (app, windows, tracks, settings, waiting for changes). `ProToolsWindowKind` classifies each window title as one kind.
- `Sources/FloEngine/`: command model and runtime: `Command`, `Scope`/`Mode`, `CommandRun`, `Engine` (key routing, double press, serial queue), `Watches`, `SpokenError` (the one failure wording table), `Context`, `Preferences`.
- `Sources/FloFeatures/`: the commands, one folder per feature, plus `FloFeatures.all`, `SessionState`, `SpokenList` and `Lifecycle` (replaces the KM Global group).
- `Sources/FloTools/`: the app: status menu, permissions, preferences panel, log header, `LoginItem`, `Updater`. Only this target links Sparkle.
- `Tests/FloToolsTests/`: Swift Testing. `Tests/Baselines/` holds the keymap baselines; `CommandReferenceTests` generates `COMMANDS.md`.
- `reference/`: frozen KM material, plus `Plug-In Views/`, which ship in the app and are copied to `~/Library/Application Support/Flo Tools/Plug-In Views/` on first launch without overwriting.
- `scripts/build-app.sh` builds and signs the app; `scripts/vo.sh` drives VoiceOver for live tests. `Resources/` holds `Info.plist`, entitlements and `Sounds/`.

Update this section when the layout changes.

## Commands

Run from the repository root.

- Build: `swift build`. Test: `swift test`.
- App bundle: `scripts/build-app.sh` (signs with the first "Apple Development" identity, or `FLO_SIGN_IDENTITY`). Always use the same identity; Accessibility and Automation permissions are tied to it.
- Install and relaunch: `scripts/build-app.sh && rm -rf "/Applications/Flo Tools.new.app" && ditto "build/Flo Tools.app" "/Applications/Flo Tools.new.app" && { pkill -x FloTools || true; } && rm -rf "/Applications/Flo Tools.app" && mv "/Applications/Flo Tools.new.app" "/Applications/Flo Tools.app" && open "/Applications/Flo Tools.app"`. A failed build or copy leaves the installed app running. Test only the `/Applications` copy, never `build/`. Check that `Program` in `~/Library/LaunchAgents/com.chikim.FloTools.plist` is `/Applications/Flo Tools.app/Contents/MacOS/FloTools`; if not, toggle Launch on Login in Preferences from the `/Applications` copy. Do not install Developer ID builds (`build/dist/`) there; their permissions are separate.
- Regenerate baselines and `COMMANDS.md`: `FLO_WRITE_BASELINES=1 swift test --filter "KeymapTests|CommandReferenceTests"`, then read the diff.
- App log: menu bar "Turn On Log", then read the newest file in `~/Library/Logs/Flo Tools/`. The unified log (`log show --last 1m --predicate 'subsystem == "com.chikim.FloTools"' --style compact`) has only warnings and errors.

## Adding or changing a command

1. For KM behavior, read `reference/macros/<group>/<macro>.md` for the original wording and steps.
2. Declare it in its feature folder with ID, name, summary (one or two sentences for `COMMANDS.md`), scope, mode condition and hotkeys (`.key("Ctrl+2")`). Reuse the shared implementation for its pattern (slots, transport toggles, counters, track lists, fade dialogs).
3. Unit test pure logic: message text, parsing, filters.
4. Regenerate baselines and `COMMANDS.md`; the diff must show only intended changes.
5. Build, test, install to `/Applications` and test live.
6. Update `.pi/HANDOFF.md` and commit, saying what was tested live.

## Testing live in Pro Tools

- Open the test session `~/Documents/Pro Tools/Demo Sessions/Can't Get Enough Pro Tools Demo/Can't Get Enough Pro Tools Intro Demo.ptx` (the Intro Demo). Never save it: no Cmd+S, Save, Save As or Save Copy In; answer Don't Save on close. Keyboard Maestro Engine must not be running.
- Press a hotkey: `osascript -e 'tell application "System Events" to key code 19 using control down'`. For a double press, send two key codes 0.05 s apart in one script.
- Check speech: `osascript -e 'tell application "VoiceOver" to return content of last phrase'`. Check the routed command in the diagnostic log (`<combo> pressed in <context> -> <command ID>`). Front window: System Events `value of attribute "AXFocusedWindow"` of the Pro Tools process.
- Move and read the VoiceOver cursor with `scripts/vo.sh` (run without arguments for usage), not Ctrl+Opt+arrows, which hit Flo Tools' Inspector keys.
- Restore any session state a test changes and record it in the journal. Say when a result was not checked with a physical keyboard.

## Code quality standard

The goal is a codebase good enough to teach from: each part has a clear job, and a reader can follow what happens without reading everything.

- Design: simple and cohesive over clever or abstract. One responsibility per module, type and function. Keep Pro Tools knowledge, command behavior, the engine, macOS infrastructure and app UI apart. Pass dependencies explicitly; justify any shared instance. Add an abstraction only when it reduces duplication, coupling or testing difficulty now: no single-implementation protocols, factories, managers, forwarding wrappers or speculative extension points.
- One source of truth: one representation per concept (command, hotkey, window condition, double press, track lookup, preferences). App code finds commands by `CommandID`; KM UIDs appear only in `reference/`. No duplicate constants, parsing or formatting.
- Implement shared command patterns once, parameterized. When the same logic appears a second time, move it into one shared function.
- One current implementation: no old code beside new, fallbacks, compatibility aliases, migration code or version branches. Preferences live in UserDefaults (`com.chikim.FloTools`) via `PreferencesStore`; KM's `flotools.json` is not read. Remove dead code and stale comments as you find them.
- Interfaces: narrow, with domain types where they prevent mistakes. Avoid boolean flags and long optional parameter lists. Keep the flow traceable: trigger -> context check -> command logic -> side effect -> spoken result. Validate at boundaries (command install, reference generation, preferences loading, Accessibility reads).
- Errors: one error model (`FloError`); core code throws meaningful errors rather than returning nil. What the user hears is decided once, in `SpokenError`; cancellation is silent. No broad catch-and-ignore except at a logged boundary.
- Logging: everything goes through `Log`; never call `Logger` or `print`. Every command run has an invocation ID on every line it causes. Log once per failure where the context is; when a required element is missing, log the bounded subtree where the lookup stopped. Track names, window titles, session names and spoken text may be logged (approved 2026-11-02). Logging never blocks the caller. The full log design is in plan.md section 4.
- Security: least privilege, minimal entitlements, hardened runtime, consistent signing. Pass values into AppleScript or shell as parameters; prefer APIs to shell commands. Network access only as the owner approved.
- Efficiency: avoid re-walking the Accessibility tree, polling faster than needed and blocking the main thread. Explain real tradeoffs in `plan.md`.
- Swift: idiomatic Swift 6; say which actor owns mutable state. Value types, small functions, no force unwraps outside tests or truly impossible cases, no hidden side effects. Consistent names across code, tests, logs and docs; avoid vague names like Manager, Helper or Utils.
- Tests: deterministic, at the right level, without mocking-only abstractions. Never weaken a test to make a change pass; if behavior changes on purpose, update the test and say why.

Before finishing: run the tests, read the whole diff, and check that no obsolete path remains, names and errors are consistent, dependencies point the right way, and the result is simpler to explain than before.

## Writing conventions

- Comments explain why, in short plain English.
- Prose files: one paragraph per line, no soft wrapping, no bold or italics for emphasis.
