"""Generate the readable reference files from the retired Keyboard Maestro export.

Flo Tools for Keyboard Maestro is retired; the Swift app is the product. `reference/Flo Tools.kmmacros` stays as the porting reference, and this script turns it into `reference/macros/`: one Markdown file per macro and `INDEX.md`. The "Ported" column of the existing index is kept, keyed by macro UID; `KeyboardMaestroParityTests` checks it against the Swift macros.

Unknown trigger types, fire types, conditions or targeting stop generation, so the reference files never silently drop data.

Usage, from the repository root:
    .venv/bin/python -I tools/km_export.py [--check]

`--check` writes nothing and exits 1 if the files on disk differ from what would be generated.
"""

import argparse
import json
import plistlib
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXPORT = ROOT / "reference" / "Flo Tools.kmmacros"
MACROS_DIR = ROOT / "reference" / "macros"

# Keyboard Maestro modifier bits (the Carbon ones), in display order.
MODIFIERS = [(4096, "Ctrl"), (2048, "Opt"), (512, "Shift"), (256, "Cmd")]

# macOS virtual key codes (ANSI layout). Sources/FloToolsCore/KeyNames.swift has the same table for the app.
KEY_NAMES = {
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
    11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
    20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
    29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
    37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
    46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Escape",
    64: "F17", 65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 71: "Keypad Clear",
    75: "Keypad /", 76: "Keypad Enter", 78: "Keypad -", 79: "F18", 80: "F19", 81: "Keypad =",
    82: "Keypad 0", 83: "Keypad 1", 84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4",
    87: "Keypad 5", 88: "Keypad 6", 89: "Keypad 7", 90: "F20", 91: "Keypad 8", 92: "Keypad 9",
    96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
    106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home",
    116: "Page Up", 117: "Forward Delete", 118: "F4", 119: "End", 120: "F2", 121: "Page Down",
    122: "F1", 123: "Left", 124: "Right", 125: "Down", 126: "Up",
}

# Macros that will not be ported. INDEX.md marks them "excluded"; their reference files stay.
# Flo Mouse moves to a separate project (owner decision, 2026-11-02). Global Macro Group only holds Toggle Flo Mouse.
EXCLUDED_GROUPS = {"82EB8E84-2FE7-4AB2-BB2F-3680048B08C2": "Flo Mouse"}
EXCLUDED_MACROS = {"0D1179E6-67B7-4B3F-AF22-8220E83AABA1": "Flo Mouse"}  # Toggle Flo Mouse

WINDOW_CONDITIONS = {"TitleIs": "is", "TitleContains": "contains", "TitleMatches": "matches"}

FOCUSED_WINDOW_CHANGES = {"FocussedWindowChanges", "FocussedWindowTitleChanges", "FocussedWindowsTitleChanged"}
APPLICATION_EVENTS = {"Launch", "Quit"}
HOTKEY_PHASES = {"Pressed", "Released"}

# Trigger keys each trigger type may have. Anything else is unknown and stops generation.
TRIGGER_KEYS = {
    "HotKey": {"MacroTriggerType", "FireType", "KeyCode", "Modifiers"},
    "FocussedWindow": {"MacroTriggerType", "ChangeType"},
    # RepeatTime belongs to KM's "while running" fire type; for Launch and Quit it has no effect.
    "Application": {"MacroTriggerType", "Application", "FireType2", "RepeatTime", "Target"},
    "StatusMenu": {"MacroTriggerType"},
}

class ExportError(Exception):
    """The export contains something this generator does not understand."""


@dataclass
class Group:
    uid: str
    name: str
    enabled: bool
    bundle_ids: list
    app_names: list
    condition: tuple  # (kind, title) or None


@dataclass
class Macro:
    uid: str
    name: str
    group: Group
    enabled: bool
    triggers: list  # raw trigger dicts, validated
    actions: list = field(default_factory=list)


# MARK: Loading and validation


def load(path=EXPORT):
    """Reads the export and returns (groups, macros) in export order, validated."""
    with open(path, "rb") as f:
        data = plistlib.load(f)
    groups = {}
    macros = []
    for record in data:
        group = parse_group(record)
        known = groups.setdefault(group.uid, group)
        if known != group:
            raise ExportError(f"group {group.uid} has conflicting metadata in different records")
        for m in record.get("Macros", []):
            for t in m.get("Triggers", []):
                validate_trigger(t, m.get("Name", ""))
            macros.append(Macro(m["UID"], m.get("Name", ""), known, m.get("IsActive", True), m.get("Triggers", []), m.get("Actions", [])))
    uids = [m.uid for m in macros] + list(groups)
    duplicates = {u for u in uids if uids.count(u) > 1}
    if duplicates:
        raise ExportError(f"duplicate UIDs: {sorted(duplicates)}")
    return list(groups.values()), macros


def exclusion(m):
    """Why a macro will not be ported, or None."""
    return EXCLUDED_GROUPS.get(m.group.uid) or EXCLUDED_MACROS.get(m.uid)


def parse_group(record):
    name = record["Name"]
    if record.get("Activate", "Normal") != "Normal":
        raise ExportError(f"group {name!r}: unsupported activation {record['Activate']!r}")
    targeting = record.get("Targeting", {})
    if targeting.get("Targeting") not in (None, "All", "Included"):
        raise ExportError(f"group {name!r}: unsupported targeting {targeting.get('Targeting')!r}")
    apps = targeting.get("TargetingApps", []) if targeting.get("Targeting") == "Included" else []
    condition = None
    if record.get("FocussedWindowTitle"):
        kind = record.get("FocussedWindowConditionType")
        if kind not in WINDOW_CONDITIONS:
            raise ExportError(f"group {name!r}: unknown window condition {kind!r}")
        condition = (kind, record["FocussedWindowTitle"])
    return Group(record["UID"], name, record.get("IsActive", True), [a["BundleIdentifier"] for a in apps], [a.get("Name", "") for a in apps], condition)


def validate_trigger(t, macro_name):
    kind = t.get("MacroTriggerType")
    if kind not in TRIGGER_KEYS:
        raise ExportError(f"macro {macro_name!r}: unknown trigger type {kind!r}")
    unknown = set(t) - TRIGGER_KEYS[kind]
    if unknown:
        raise ExportError(f"macro {macro_name!r}: unknown {kind} trigger fields {sorted(unknown)}")
    if kind == "HotKey" and t.get("FireType", "Pressed") not in HOTKEY_PHASES:
        raise ExportError(f"macro {macro_name!r}: unknown hotkey fire type {t.get('FireType')!r}")
    if kind == "FocussedWindow" and t.get("ChangeType") not in FOCUSED_WINDOW_CHANGES:
        raise ExportError(f"macro {macro_name!r}: unknown focused window change {t.get('ChangeType')!r}")
    if kind == "Application":
        if t.get("Target") != "Specific" or not t.get("Application", {}).get("BundleIdentifier"):
            raise ExportError(f"macro {macro_name!r}: application trigger without a specific bundle ID")
        if t.get("FireType2") not in APPLICATION_EVENTS:
            raise ExportError(f"macro {macro_name!r}: unknown application event {t.get('FireType2')!r}")


# MARK: Names


def key_name(code, modifiers):
    parts = [name for bit, name in MODIFIERS if modifiers & bit]
    parts.append(KEY_NAMES.get(code, f"key{code}"))
    return "+".join(parts)


def trigger_text(t):
    """Short human-readable trigger, for the reference files."""
    kind = t["MacroTriggerType"]
    if kind == "HotKey":
        text = key_name(t["KeyCode"], t["Modifiers"])
        return text + " (released)" if t.get("FireType") == "Released" else text
    if kind == "FocussedWindow":
        return f"focused window: {t['ChangeType']}"
    if kind == "Application":
        return f"{t['Application'].get('Name', t['Application']['BundleIdentifier'])} {t['FireType2'].lower()}"
    return "status menu"


# MARK: Reference files


def slug(s):
    return re.sub(r"[^\w\- .]+", "_", s).strip()[:80]


def describe(a, depth, out):
    pad = "  " * depth
    kind = a.get("MacroActionType")
    title = a.get("ActionName")
    head = f"{pad}- {kind}" + (f" \"{title}\"" if title else "")
    if a.get("IsDisabled"):
        head += " [DISABLED]"
    if kind == "ExecuteJavaScriptForAutomation":
        out.append(head)
        out.append(f"{pad}  ```javascript")
        for line in (a.get("Text") or "").splitlines():
            out.append(f"{pad}  {line}")
        out.append(f"{pad}  ```")
        return
    if kind == "SimulateKeystroke":
        out.append(f"{head}: {key_name(a.get('KeyCode', -1), a.get('Modifiers', 0))}")
        return
    if kind == "SetVariableToText":
        out.append(f"{head}: {a.get('Variable')} = {a.get('Text')!r}")
        return
    if kind == "IfThenElse":
        c = a.get("Conditions", {})
        out.append(f"{head} ({c.get('ConditionListMatch')}):")
        for cond in c.get("ConditionList", []):
            out.append(f"{pad}  - if {json.dumps(cond, default=str)}")
        out.append(f"{pad}  then:")
        for x in a.get("ThenActions", []):
            describe(x, depth + 2, out)
        if a.get("ElseActions"):
            out.append(f"{pad}  else:")
            for x in a["ElseActions"]:
                describe(x, depth + 2, out)
        return
    if kind == "Switch":
        out.append(f"{head}: {json.dumps({k: v for k, v in a.items() if k not in ('Cases', 'MacroActionType')}, default=str)}")
        for case in a.get("Cases", []):
            out.append(f"{pad}  case {json.dumps({k: v for k, v in case.items() if k != 'Actions'}, default=str)}:")
            for x in case.get("Actions", []):
                describe(x, depth + 2, out)
        return
    rest = {k: v for k, v in a.items() if k not in ("MacroActionType", "ActionUID", "Actions")}
    out.append(f"{head}: {json.dumps(rest, default=str)}")
    for x in a.get("Actions", []):
        describe(x, depth + 1, out)


def render_macro(m):
    triggers = "; ".join(trigger_text(t) for t in m.triggers) or "none"
    lines = [f"# {m.name}", "", f"- Group: {m.group.name}", f"- UID: {m.uid}", f"- Enabled: {m.enabled}", f"- Triggers: {triggers}", "", "## Actions", ""]
    for a in m.actions:
        describe(a, 0, lines)
    return "\n".join(lines) + "\n"


def macro_paths(macros):
    """Relative Markdown path for each macro UID. Name collisions after sanitizing get a number."""
    paths = {}
    used = set()
    for m in macros:
        base = f"{slug(m.group.name)}/{slug(m.name) or m.uid}"
        path, n = f"{base}.md", 2
        while path.lower() in used:
            path, n = f"{base} ({n}).md", n + 1
        used.add(path.lower())
        paths[m.uid] = path
    return paths


def table_cell(text):
    return text.replace("|", "/")


def read_ported(index_text, paths):
    """The "Ported" column of an existing INDEX.md, keyed by macro UID. Rows of the older index without a UID column are matched by their link."""
    uid_by_path = {path: uid for uid, path in paths.items()}
    ported = {}
    for line in index_text.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 6 and re.fullmatch(r"[0-9A-F-]{36}", cells[4]):
            ported[cells[4]] = cells[5]
        elif len(cells) == 5 and (link := re.search(r"\]\(<(.+)>\)$", cells[1])) and link[1] in uid_by_path:
            ported[uid_by_path[link[1]]] = cells[4]
    return {uid: status for uid, status in ported.items() if status and not status.startswith("excluded")}


def render_index(groups, macros, paths, ported):
    out = [
        "# Flo Tools macro index",
        "",
        f"{len(macros)} macros in {len(groups)} groups. Generated by `tools/km_export.py` from the retired Keyboard Maestro export. The Ported column is edited by hand and kept on regeneration, except \"excluded\", which comes from the generator's exclusion list. `KeyboardMaestroParityTests` checks that \"yes\" marks exactly the ported macros.",
        "",
        "## Groups",
        "",
        "| Group | Active | Target | Window title condition |",
        "|---|---|---|---|",
    ]
    for g in groups:
        apps = ", ".join(g.app_names) or "global"
        cond = f"{g.condition[0]} `{g.condition[1]}`" if g.condition else ""
        out.append(f"| {g.name} | {g.enabled} | {apps} | {cond} |")
    out += ["", "## Macros", "", "| Group | Macro | Trigger | Enabled | UID | Ported |", "|---|---|---|---|---|---|"]
    for m in sorted(macros, key=lambda m: (m.group.name, m.name, m.uid)):
        triggers = "; ".join(trigger_text(t) for t in m.triggers)
        reason = exclusion(m)
        status = f"excluded ({reason})" if reason else ported.get(m.uid, "")
        out.append(
            f"| {m.group.name} | [{table_cell(m.name)}](<{paths[m.uid]}>) | {table_cell(triggers)} | {m.enabled} | {m.uid} | {status} |"
        )
    return "\n".join(out) + "\n"


def reference_files(groups, macros, existing_index):
    """All files of reference/macros, as {relative path: text}."""
    paths = macro_paths(macros)
    files = {paths[m.uid]: render_macro(m) for m in macros}
    files["INDEX.md"] = render_index(groups, macros, paths, read_ported(existing_index, paths))
    return files


def write_reference(directory, files):
    """Replaces the generated Markdown files in `directory`. Only `.md` files there are deleted, so a wrong path cannot wipe other data."""
    directory.mkdir(parents=True, exist_ok=True)
    for old in directory.rglob("*.md"):
        old.unlink()
    for sub in sorted((p for p in directory.iterdir() if p.is_dir()), reverse=True):
        if not any(sub.iterdir()):
            sub.rmdir()
    for rel, text in files.items():
        path = directory / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)


def current_reference(directory):
    return {p.relative_to(directory).as_posix(): p.read_text() for p in directory.rglob("*.md")} if directory.exists() else {}


# MARK: Commands


def macros_command(check):
    groups, macros = load()
    index = MACROS_DIR / "INDEX.md"
    files = reference_files(groups, macros, index.read_text() if index.exists() else "")
    if check:
        if current_reference(MACROS_DIR) != files:
            print(f"out of date: {MACROS_DIR.relative_to(ROOT)}")
            return 1
        return 0
    write_reference(MACROS_DIR, files)
    print(f"wrote {len(macros)} macros to {MACROS_DIR.relative_to(ROOT)}")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="write nothing; exit 1 if generated files are out of date")
    args = parser.parse_args(argv)
    try:
        return macros_command(args.check)
    except ExportError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
