"""The tool's judge against the fixture the server's judge reads too.

    python -m unittest tools/tutorial_translate/test_translate.py

Phase 9 of docs/PLAN-PRIPREMA.md: the app's „Translate…" judges a translation
on the server (chess_backend/services/tutorialTranslation.js), and this tool
judges one here. The two are held to one file of cases,
chess_backend/test/fixtures/translation_cases.json, which the server's test
(chess_backend/test/lesson_translation.test.js) reads as well — so a rule that
changes on one side and not the other turns one of the two red.
"""

import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import translate  # noqa: E402

FIXTURE = os.path.join(HERE, '..', '..', 'chess_backend', 'test', 'fixtures',
                       'translation_cases.json')

# The server's names for the tool's reasons.
KINDS = (
    ('missing from the translation', 'missing'),
    ('translated to nothing', 'empty'),
    ('notation differs', 'notation'),
    ('must not contain {', 'braces'),
    ('Cyrillic letters', 'cyrillic'),
    ('invented by the model', 'invented'),
)


def kind_of(reason):
    for words, kind in KINDS:
        if words in reason:
            return kind
    raise AssertionError('a reason the fixture has no name for: %s' % reason)


class SharedCases(unittest.TestCase):
    def test_every_case(self):
        with open(FIXTURE, encoding='utf-8') as fh:
            cases = json.load(fh)['cases']
        self.assertGreater(len(cases), 10)
        for case in cases:
            with self.subTest(case['name']):
                faults, _ = translate.judge(case['source'], case['translation'],
                                            case['language'])
                self.assertEqual(
                    {key: kind_of(reason) for key, reason in faults.items()},
                    case['faults'])


if __name__ == '__main__':
    unittest.main()
