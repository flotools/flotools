# Porting Flo Tools from Keyboard Maestro to Swift

This branch (`swift`) is an orphan branch. It holds a native Swift rewrite of Flo Tools that talks to Pro Tools through the macOS Accessibility API instead of Keyboard Maestro, JXA and System Events.

## Reference material

- `reference/Flo Tools.kmmacros`: the original Keyboard Maestro export (version 2026.8.2), copied from `FloTools Installer.app/Contents/Resources` on the `development` branch. It is a plist, so `plistlib` reads it.
- `reference/macros/`: one Markdown file per macro, generated from the export. `reference/macros/INDEX.md` lists every macro with its group, hotkey and a "Ported" column to track progress.
- `reference/README (Keyboard Maestro).md`: the user-facing documentation of the Keyboard Maestro version.
- `reference/Plug-In Views/` and `reference/Flo Tools Key Set.ptpreset`: support files shipped with the installer.

Regenerate the per-macro files with `.venv/bin/python -I tools/km_export.py`.

## What the export contains

- 300 macros in 12 groups. 270 have hotkey triggers. The "Flo Mouse" group is disabled by default and toggled on demand.
- Groups are scoped by app (Pro Tools, bundle ID `com.avid.ProTools`) and by a front-window title condition, for example `^(Mix|Edit):`, `^Plug-in:`, `Audio Suite:`, `Fade In`, `Batch Fades`. The Swift version needs the same context rules so the same key can do different things in different windows.
- 294 JXA actions, about 259 KB of script. Common building blocks:
  - VoiceOver speech with `vo.output` (226 macros) and reading the VoiceOver cursor with `vo.voCursor.textUnderCursor()` (78 macros) or the keyboard cursor (15).
  - System Events UI scripting of Pro Tools windows: finding the Mix/Edit window, track groups by name, buttons, pop-up buttons and menus, then `click()` (151 macros).
  - Single-press versus double-press detection through the KM variables `command` and `FTTimeout` (89 macros).
  - `chooseFromList` dialogs (12), sounds (77), simulated keystrokes (71 KM actions) and mouse clicks at coordinates (40 KM actions).
  - KM state variables such as `FTEventIndex`, `FTPluginControlIndex`, `FTLevelMonitor`, `FTGRMonitor` and `FTPreference`.

## Swift equivalents

| Keyboard Maestro / JXA | Swift |
|---|---|
| Hotkey triggers and macro groups | Global hotkeys (Carbon `RegisterEventHotKey` or a `CGEventTap`) with a context check on the frontmost app and focused window title |
| System Events UI scripting | `AXUIElement` wrapper: attributes, children, search by role and title, `AXPress` |
| `vo.output` | VoiceOver's `output` Apple event (`VOAS`/`outp`) sent with `NSAppleEventDescriptor`. Accessibility announcements from a background app are not spoken (tested 2026-11-02) |
| `vo.voCursor.textUnderCursor()` | No public AX API exposes the VoiceOver cursor; a `get` Apple event for `text under cursor of vo cursor` (`votx` of `vocu`) |
| KM variables | `UserDefaults` for preferences, in-memory state for the rest |
| Double-press detection | A small timer-based dispatcher instead of polling a shared variable |
| `SimulateKeystroke`, `MouseMoveAndClick` | `CGEvent` keyboard and mouse events |
| `chooseFromList`, prompts | Native `NSAlert` or `NSPanel` dialogs that work well with VoiceOver |

## Plan

1. Build the core: a menu bar agent app, accessibility permission check, AX element helpers, VoiceOver speech, hotkey registration with context rules, and the double-press dispatcher.
2. Port macros group by group, starting with a few representative ones to prove the core (for example "Speak/Open Send B" and "List Soloed Tracks").
3. Mark each ported macro in `reference/macros/INDEX.md` and test it against Pro Tools with VoiceOver running.
