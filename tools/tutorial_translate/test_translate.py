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


class SeveralBeatsOnOneMove(unittest.TestCase):
    """Two comments in a row on one move are two beats (phase 6 of
    docs/PLAN-PRIPREMA.md): each is its own item, each is written back in its
    own place with its own commands, and nothing else moves."""

    def test_each_comment_is_its_own_item_and_goes_back_to_its_place(self):
        tutorial = {'positionList': [{
            'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            'kind': 'show',
            'pgn': '1. e4 { The king pawn. [%cal Ge2e4] } '
                   '{ And the bishop. [%cal Gf1c4] } e5 *',
        }]}
        items = translate.extract(tutorial)
        self.assertEqual(items, {'p1.c1': 'The king pawn.', 'p1.c2': 'And the bishop.'})
        merged = translate.merge(tutorial, {'p1.c1': 'Kraljev pešak.', 'p1.c2': 'I lovac.'})
        self.assertEqual(merged['positionList'][0]['pgn'],
                         '1. e4 { Kraljev pešak. [%cal Ge2e4] } '
                         '{ I lovac. [%cal Gf1c4] } e5 *')
        translate.prove_untouched(tutorial, merged)


if __name__ == '__main__':
    unittest.main()
