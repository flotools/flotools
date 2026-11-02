"""Extract Flo Tools.kmmacros into readable per-macro files and an index.

Usage: python -I tools/extract_macros.py [reference/Flo Tools.kmmacros] [reference/macros]
"""

import json
import plistlib
import re
import shutil
import sys
from pathlib import Path

# Keyboard Maestro modifier bits.
MODS = [(4096, "Ctrl"), (2048, "Opt"), (512, "Shift"), (256, "Cmd")]

# macOS virtual key codes (ANSI layout).
KEYS = {
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
    11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
    20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
    29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
    37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
    46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Escape",
    65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 71: "Keypad Clear", 75: "Keypad /",
    76: "Keypad Enter", 78: "Keypad -", 81: "Keypad =", 82: "Keypad 0", 83: "Keypad 1",
    84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4", 87: "Keypad 5", 88: "Keypad 6",
    89: "Keypad 7", 91: "Keypad 8", 92: "Keypad 9", 96: "F5", 97: "F6", 98: "F7",
    99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16", 107: "F14",
    109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
    117: "Forward Delete", 118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
    123: "Left", 124: "Right", 125: "Down", 126: "Up", 64: "F17", 79: "F18", 80: "F19",
    90: "F20",
}


def keyname(code, mods):
    parts = [n for bit, n in MODS if mods & bit]
    parts.append(KEYS.get(code, f"key{code}"))
    return "+".join(parts)


def trigger_text(t):
    kind = t.get("MacroTriggerType")
    if kind == "HotKey":
        s = keyname(t.get("KeyCode", -1), t.get("Modifiers", 0))
        if t.get("FireType") and t["FireType"] != "Pressed":
            s += f" ({t['FireType']})"
        return s
    rest = {k: v for k, v in t.items() if k != "MacroTriggerType"}
    return f"{kind} {json.dumps(rest, default=str)}"


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
        out.append(f"{head}: {keyname(a.get('KeyCode', -1), a.get('Modifiers', 0))}")
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
    nested = [k for k in ("Actions",) if k in a]
    rest = {k: v for k, v in a.items() if k not in ("MacroActionType", "ActionUID", "Actions")}
    out.append(f"{head}: {json.dumps(rest, default=str)}")
    for k in nested:
        for x in a[k]:
            describe(x, depth + 1, out)


def main():
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "reference/Flo Tools.kmmacros")
    dst = Path(sys.argv[2] if len(sys.argv) > 2 else "reference/macros")
    data = plistlib.load(src.open("rb"))
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)

    groups = {}
    index = []
    for g in data:
        gname = g["Name"]
        groups.setdefault(gname, {k: v for k, v in g.items() if k not in ("Macros", "CreationDate", "ModificationDate")})
        for m in g.get("Macros", []):
            name = m.get("Name", "")
            trig = [trigger_text(t) for t in m.get("Triggers", [])]
            lines = [f"# {name}", "", f"- Group: {gname}", f"- UID: {m.get('UID')}",
                     f"- Enabled: {m.get('IsActive', True)}", f"- Triggers: {'; '.join(trig) or 'none'}", "", "## Actions", ""]
            for a in m.get("Actions", []):
                describe(a, 0, lines)
            path = dst / slug(gname) / f"{slug(name) or m.get('UID')}.md"
            n = 2
            while path.exists():
                path = path.with_name(f"{slug(name)} ({n}).md")
                n += 1
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("\n".join(lines) + "\n")
            index.append((gname, name, "; ".join(trig), m.get("IsActive", True), path.relative_to(dst).as_posix()))

    out = ["# Flo Tools macro index", "", f"{len(index)} macros in {len(groups)} groups.", "",
           "## Groups", "", "| Group | Active | Target | Window title condition |", "|---|---|---|---|"]
    for gname, g in groups.items():
        apps = ", ".join(a.get("Name", "") for a in g.get("Targeting", {}).get("TargetingApps", [])) or "global"
        cond = f"{g.get('FocussedWindowConditionType', '')} `{g.get('FocussedWindowTitle', '')}`" if g.get("FocussedWindowTitle") else ""
        out.append(f"| {gname} | {g.get('IsActive', True)} | {apps} | {cond} |")
    out += ["", "## Macros", "", "| Group | Macro | Trigger | Enabled | Ported |", "|---|---|---|---|---|"]
    for gname, name, trig, active, rel in sorted(index):
        out.append(f"| {gname} | [{name.replace('|', '/')}](<{rel}>) | {trig.replace('|', '/')} | {active} | |")
    (dst / "INDEX.md").write_text("\n".join(out) + "\n")
    print(f"wrote {len(index)} macros to {dst}")


if __name__ == "__main__":
    main()
