"""Every user-facing string must come from the translation table.

Hardcoded English in the UI means adding a language later requires editing each
call site, and it silently drifts out of sync with whatever the translators are
given.
"""
import csv
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
UI_FILES = sorted((ROOT / "ui").glob("*.gd"))
CSV_PATH = ROOT / "localisation" / "strings.csv"

# Assignments to a Control's visible text.
TEXT_ASSIGNMENT = re.compile(r'\.text\s*=\s*(.+)')
TR_KEY = re.compile(r'\btr\(\s*"([A-Z0-9_]+)"\s*\)')


def load_keys():
    with CSV_PATH.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.reader(handle))
    header, body = rows[0], rows[1:]
    return header, {row[0] for row in body if row and row[0]}


class LocalisationTests(unittest.TestCase):
    def test_translation_table_exists_with_english_and_vietnamese(self):
        self.assertTrue(CSV_PATH.exists(), "no localisation/strings.csv")
        header, keys = load_keys()
        self.assertEqual(header[0], "keys")
        for locale in ("en", "vi"):
            self.assertIn(locale, header, "no %s column in the translation table" % locale)
        self.assertGreater(len(keys), 0, "translation table has no entries")

    def test_no_hardcoded_user_facing_text_in_the_ui(self):
        offenders = []
        for path in UI_FILES:
            for number, line in enumerate(path.read_text().splitlines(), 1):
                match = TEXT_ASSIGNMENT.search(line)
                if not match:
                    continue
                value = match.group(1).strip()
                if not value.startswith('"'):
                    continue
                # Icon glyphs carry no language and need no translation.
                literal = re.match(r'"(?:\\.|[^"\\])*"', value).group(0)
                visible_text = re.sub(r"%[-+0-9.]*[A-Za-z]", "", literal)
                if not re.search(r"[A-Za-z]", visible_text):
                    continue
                offenders.append("%s:%d %s" % (path.name, number, value))
        self.assertEqual(offenders, [], "hardcoded UI text:\n  " + "\n  ".join(offenders))

    def test_every_translation_key_used_in_the_ui_exists(self):
        _header, keys = load_keys()
        missing = []
        for path in UI_FILES:
            for number, line in enumerate(path.read_text().splitlines(), 1):
                for key in TR_KEY.findall(line):
                    if key not in keys:
                        missing.append("%s:%d %s" % (path.name, number, key))
        self.assertEqual(missing, [], "keys used but not translated:\n  " + "\n  ".join(missing))


if __name__ == "__main__":
    unittest.main()
