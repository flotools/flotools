"""Tests for km_export.py. Run from the repository root:

    .venv/bin/python -I -m unittest discover -s tools

They use small exports built in a temporary folder, plus one check that the real reference files are up to date.
"""

import plistlib
import re
import tempfile
import unittest
from pathlib import Path

import km_export as km


def group_record(uid="G1", name="Flo Tools", macros=(), **extra):
    record = {
        "UID": uid,
        "Name": name,
        "Activate": "Normal",
        "Targeting": {"Targeting": "Included", "TargetingApps": [{"BundleIdentifier": "com.avid.ProTools", "Name": "Pro Tools"}]},
        "Macros": list(macros),
    }
    record.update(extra)
    return record


def hotkey(code=1, modifiers=0, fire="Pressed"):
    return {"MacroTriggerType": "HotKey", "KeyCode": code, "Modifiers": modifiers, "FireType": fire}


def macro_record(uid, name="Speak", triggers=(), actions=()):
    return {"UID": uid, "Name": name, "IsActive": True, "Triggers": list(triggers), "Actions": list(actions)}


class TempExport:
    """Writes records as a .kmmacros plist and loads it with km_export."""

    def __init__(self, records):
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "test.kmmacros"
        with open(self.path, "wb") as f:
            plistlib.dump(records, f)

    def __enter__(self):
        return self.path

    def __exit__(self, *exc):
        self.dir.cleanup()


def load(records):
    with TempExport(records) as path:
        return km.load(path)


class KeyNameTests(unittest.TestCase):
    def test_modifier_order_and_names(self):
        self.assertEqual(km.key_name(1, 2048 | 512), "Opt+Shift+S")
        self.assertEqual(km.key_name(78, 4096 | 2048), "Ctrl+Opt+Keypad -")
        self.assertEqual(km.key_name(124, 4096 | 256), "Ctrl+Cmd+Right")

    def test_unknown_code_is_named_by_number(self):
        self.assertEqual(km.key_name(200, 0), "key200")

    def test_released_hotkey_is_marked(self):
        self.assertEqual(km.trigger_text(hotkey(50, 0, "Released")), "` (released)")

    def test_same_table_as_swift(self):
        # The two tables are kept by hand (plan.md section 8), so this catches drift.
        swift = (km.ROOT / "Sources" / "FloSystem" / "KeyNames.swift").read_text()
        body = swift[swift.index("keyNames: [UInt32: String] = [") : swift.index("    ]\n")]
        pairs = re.findall(r'(\d+): "((?:[^"\\]|\\.)*)"', body)
        table = {int(code): name.replace("\\\\", "\\") for code, name in pairs}
        self.assertEqual(table, km.KEY_NAMES)


class ValidationTests(unittest.TestCase):
    def assertRejected(self, trigger, message):
        with self.assertRaisesRegex(km.ExportError, message):
            km.validate_trigger(trigger, "Test")

    def test_known_triggers_pass(self):
        km.validate_trigger(hotkey(), "Test")
        km.validate_trigger({"MacroTriggerType": "FocussedWindow", "ChangeType": "FocussedWindowTitleChanges"}, "Test")
        km.validate_trigger({"MacroTriggerType": "StatusMenu"}, "Test")
        km.validate_trigger({"MacroTriggerType": "Application", "Target": "Specific", "FireType2": "Quit", "Application": {"BundleIdentifier": "com.avid.ProTools"}}, "Test")

    def test_unknown_trigger_type(self):
        self.assertRejected({"MacroTriggerType": "USBDevice"}, "unknown trigger type")

    def test_unknown_trigger_field(self):
        self.assertRejected({**hotkey(), "Repeat": True}, "unknown HotKey trigger fields")

    def test_unknown_fire_type(self):
        self.assertRejected(hotkey(fire="Tapped"), "unknown hotkey fire type")

    def test_unknown_window_change(self):
        self.assertRejected({"MacroTriggerType": "FocussedWindow", "ChangeType": "Moved"}, "unknown focused window change")

    def test_application_trigger_needs_a_bundle_id(self):
        self.assertRejected({"MacroTriggerType": "Application", "Target": "Front", "FireType2": "Launch"}, "without a specific bundle ID")

    def test_unknown_application_event(self):
        self.assertRejected({"MacroTriggerType": "Application", "Target": "Specific", "FireType2": "Hide", "Application": {"BundleIdentifier": "x"}}, "unknown application event")

    def test_group_window_condition(self):
        group = km.parse_group(group_record(FocussedWindowTitle="^Mix:", FocussedWindowConditionType="TitleMatches"))
        self.assertEqual(group.condition, ("TitleMatches", "^Mix:"))
        self.assertEqual(group.bundle_ids, ["com.avid.ProTools"])
        with self.assertRaisesRegex(km.ExportError, "unknown window condition"):
            km.parse_group(group_record(FocussedWindowTitle="Mix", FocussedWindowConditionType="TitleStartsWith"))

    def test_group_activation_and_targeting(self):
        with self.assertRaisesRegex(km.ExportError, "unsupported activation"):
            km.parse_group(group_record(Activate="OneAction"))
        with self.assertRaisesRegex(km.ExportError, "unsupported targeting"):
            km.parse_group(group_record(Targeting={"Targeting": "Excluded"}))
        self.assertEqual(km.parse_group(group_record(Targeting={"Targeting": "All"})).bundle_ids, [])


class LoadTests(unittest.TestCase):
    def test_groups_split_over_records_are_merged(self):
        groups, macros = load([group_record(macros=[macro_record("M1")]), group_record(macros=[macro_record("M2")])])
        self.assertEqual([g.uid for g in groups], ["G1"])
        self.assertEqual([m.uid for m in macros], ["M1", "M2"])
        self.assertIs(macros[0].group, macros[1].group)

    def test_conflicting_group_metadata(self):
        with self.assertRaisesRegex(km.ExportError, "conflicting metadata"):
            load([group_record(name="A"), group_record(name="B")])

    def test_duplicate_uids(self):
        with self.assertRaisesRegex(km.ExportError, "duplicate UIDs"):
            load([group_record(macros=[macro_record("M1"), macro_record("M1")])])

    def test_invalid_trigger_stops_loading(self):
        with self.assertRaises(km.ExportError):
            load([group_record(macros=[macro_record("M1", triggers=[{"MacroTriggerType": "Clipboard"}])])])


class ReferenceTests(unittest.TestCase):
    UID_A = "11111111-1111-1111-1111-111111111111"
    UID_B = "22222222-2222-2222-2222-222222222222"
    MOUSE = "33333333-3333-3333-3333-333333333333"
    MOUSE_GROUP = "82EB8E84-2FE7-4AB2-BB2F-3680048B08C2"

    def export(self):
        return load([
            group_record(macros=[
                macro_record(self.UID_A, "Speak/Open Send B", [hotkey(19, 4096)], [{"MacroActionType": "SimulateKeystroke", "KeyCode": 5, "Modifiers": 768}]),
                macro_record(self.UID_B, "Speak:Open Send B", [hotkey(20, 4096)]),
            ]),
            group_record(uid=self.MOUSE_GROUP, name="Flo Mouse", macros=[macro_record(self.MOUSE, "Click")]),
        ])

    def test_paths_are_sanitized_and_collisions_numbered(self):
        _, macros = self.export()
        paths = km.macro_paths(macros)
        self.assertEqual(paths[self.UID_A], "Flo Tools/Speak_Open Send B.md")
        self.assertEqual(paths[self.UID_B], "Flo Tools/Speak_Open Send B (2).md")

    def test_macro_file(self):
        _, macros = self.export()
        text = km.render_macro(macros[0])
        self.assertIn("- Triggers: Ctrl+2\n", text)
        self.assertIn("- SimulateKeystroke: Shift+Cmd+G\n", text)

    def test_ported_column_survives_regeneration(self):
        groups, macros = self.export()
        first = km.reference_files(groups, macros, "")["INDEX.md"]
        edited = first.replace(f"| {self.UID_A} |  |", f"| {self.UID_A} | yes |")
        self.assertNotEqual(edited, first)
        second = km.reference_files(groups, macros, edited)["INDEX.md"]
        self.assertEqual(second, edited)

    def test_excluded_comes_from_the_generator(self):
        groups, macros = self.export()
        index = km.reference_files(groups, macros, "")["INDEX.md"]
        self.assertIn(f"| {self.MOUSE} | excluded (Flo Mouse) |", index)
        # A hand-written "excluded" is not kept, so the exclusion list stays the one source.
        paths = km.macro_paths(macros)
        self.assertEqual(km.read_ported(f"| G | M | T | True | {self.UID_A} | excluded (old) |", paths), {})

    def test_older_index_rows_match_by_link(self):
        _, macros = self.export()
        paths = km.macro_paths(macros)
        old = f"| Flo Tools | [Speak/Open Send B](<{paths[self.UID_A]}>) | Ctrl+2 | True | yes |"
        self.assertEqual(km.read_ported(old, paths), {self.UID_A: "yes"})

    def test_write_replaces_only_markdown(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / "Old Group").mkdir()
            (directory / "Old Group" / "Gone.md").write_text("old")
            (directory / "keep.txt").write_text("not generated")
            km.write_reference(directory, {"INDEX.md": "index\n", "Flo Tools/A.md": "a\n"})
            self.assertFalse((directory / "Old Group").exists())
            self.assertEqual((directory / "keep.txt").read_text(), "not generated")
            self.assertEqual(km.current_reference(directory), {"INDEX.md": "index\n", "Flo Tools/A.md": "a\n"})


class RepositoryTests(unittest.TestCase):
    def test_reference_files_are_up_to_date(self):
        self.assertEqual(km.main(["--check"]), 0)


if __name__ == "__main__":
    unittest.main()
