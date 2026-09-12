// The user's manual names only doors that exist — docs/PLAN-PRIRUCNIK.md.
//
// The manual lives on the site (`site/mislisha/manual/`), not in the app, and
// it quotes the app's own words: „press Save tutorial", „open Export video".
// A label renamed in the app and not in the manual sends a reader looking for
// a button that is no longer there, and nothing else in the repository would
// notice. So every label a page quotes — and only labels are put in
// `<span class="ui">` — must be a string literal in `chess_app/lib`.
//
// It is also what makes a worker's prose checkable. Three reports in a row on
// this project had accurate numbers and invented sections, and a manual is
// nothing but sections: an invented button fails here, not in a reader's hands.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/user_manual.dart';

const _manualDir = '../site/mislisha/manual';

/// The string literals of one Dart source, as the compiler would join them.
///
/// Read by walking the source rather than by a regular expression over it,
/// because a regular expression cannot tell code from writing about code: this
/// repository's comments quote retired labels — „Not 'Snimljeni časovi' any
/// more" — and a label the manual still names would pass by matching the
/// comment that says it is gone. Comments are skipped; adjacent literals are
/// joined, as a long sentence is written across lines; an interpolation becomes
/// a space, so „Resume session" matches `'Resume session ${code}'`.
List<String> literalsIn(String src) {
  final spans = <({int start, int end, String text})>[];
  const hole = ' ';
  var i = 0;
  while (i < src.length) {
    if (src.startsWith('//', i)) {
      final end = src.indexOf('\n', i);
      i = end < 0 ? src.length : end;
      continue;
    }
    if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      i = end < 0 ? src.length : end + 2;
      continue;
    }
    final c = src[i];
    if (c != "'" && c != '"') {
      i++;
      continue;
    }
    final start = i;
    final raw = i > 0 && src[i - 1] == 'r';
    final quote = src.startsWith(c * 3, i) ? c * 3 : c;
    final buf = StringBuffer();
    var j = i + quote.length;
    while (j < src.length && !src.startsWith(quote, j)) {
      if (quote.length == 1 && src[j] == '\n') break;
      if (!raw && src[j] == r'\' && j + 1 < src.length) {
        buf.write(src[j + 1] == 'n' ? '\n' : src[j + 1]);
        j += 2;
      } else if (!raw && src.startsWith(r'${', j)) {
        j++; // past the `$`, so the count starts on the brace it opens
        var depth = 0;
        do {
          if (src[j] == '{') depth++;
          if (src[j] == '}') depth--;
          j++;
        } while (j < src.length && depth > 0);
        buf.write(hole);
      } else if (!raw &&
          src[j] == r'$' &&
          j + 1 < src.length &&
          RegExp('[A-Za-z_]').hasMatch(src[j + 1])) {
        j++;
        while (j < src.length && RegExp('[A-Za-z0-9_]').hasMatch(src[j])) {
          j++;
        }
        buf.write(hole);
      } else {
        buf.write(src[j]);
        j++;
      }
    }
    i = j + quote.length;
    final text = buf.toString();
    // Joined to the literal before it when only whitespace stands between.
    if (spans.isNotEmpty &&
        src.substring(spans.last.end, start).trim().isEmpty) {
      final last = spans.removeLast();
      spans.add((start: last.start, end: i, text: last.text + text));
    } else {
      spans.add((start: start, end: i, text: text));
    }
  }
  return [
    for (final s in spans) s.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
  ];
}

/// Every string literal in `lib/`.
Set<String> _literalsOfLib() => {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          ...literalsIn(file.readAsStringSync()),
    };

String _unescapeHtml(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&');

List<File> _pages() {
  final dir = Directory(_manualDir);
  return dir.existsSync()
      ? (dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.html'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
}

String _name(File page) =>
    page.uri.pathSegments.last.replaceAll(RegExp(r'\.html$'), '');

/// The labels a page quotes, in the order it quotes them.
List<String> labelsIn(String html) => [
      for (final m in RegExp(r'<span class="ui">(.*?)</span>', dotAll: true)
          .allMatches(html))
        _unescapeHtml(m[1]!).replaceAll(RegExp(r'\s+'), ' ').trim(),
    ];

/// The labels in [html] that are not a string literal in [literals].
List<String> missingLabels(String html, Set<String> literals) => [
      for (final label in labelsIn(html))
        if (!literals.contains(label)) label
    ];

void main() {
  final pages = _pages();

  test('the manual exists, and the app links to its contents page', () {
    expect(pages, isNotEmpty, reason: 'no pages under $_manualDir');
    expect(File('$_manualDir/index.html').existsSync(), isTrue);
    expect(kUserManualUrl, endsWith('/mislisha/manual/'),
        reason: 'the site serves the contents page at this path, and the app '
            'must open that one');
  });

  test('every label a page quotes is a label the app has', () {
    final literals = _literalsOfLib();
    final missing = <String>[
      for (final page in pages)
        for (final label in missingLabels(page.readAsStringSync(), literals))
          '${_name(page)}: „$label"',
    ];
    expect(missing, isEmpty,
        reason: 'quoted in the manual and found nowhere in chess_app/lib — '
            'renamed in the app, or never there:\n${missing.join('\n')}');
  });

  test('the contents page reaches every page, and every page leads back', () {
    final index = File('$_manualDir/index.html').readAsStringSync();
    for (final page in pages) {
      final name = _name(page);
      if (name == 'index') continue;
      expect(index, contains('href="/mislisha/manual/$name"'),
          reason: '$name is a page nobody can reach from the contents');
      expect(page.readAsStringSync(), contains('href="/mislisha/manual/"'),
          reason: '$name has no way back to the contents');
    }
  });

  test('a page has no placeholder, no image and no Serbian', () {
    // The deploy script refuses a page with a placeholder left in it; the
    // manual is words only until the app is frozen (the owner, 11.9.2026);
    // and it is written in English.
    final serbian = RegExp('[čćžšđČĆŽŠĐЀ-ӿ]');
    for (final page in pages) {
      final html = page.readAsStringSync();
      expect(html, isNot(contains('{{')), reason: _name(page));
      expect(html, isNot(contains('<img')), reason: _name(page));
      expect(serbian.hasMatch(html), isFalse, reason: _name(page));
    }
  });

  group('the check itself', () {
    // Proved on a fixture as well as by mutation: a check that reads HTML with
    // a regular expression is only as good as the shapes it was tried on.
    final literals = {'Save tutorial', 'Resume session', 'Undo (Ctrl+Z)'};

    test('finds a label, however it is wrapped or escaped', () {
      expect(labelsIn('<p>Press <span class="ui">Save\n  tutorial</span>.</p>'),
          ['Save tutorial']);
      expect(
          labelsIn('<span class="ui">Undo (Ctrl+Z)</span>'), ['Undo (Ctrl+Z)']);
      expect(labelsIn('<span class="ui">Q&amp;A</span>'), ['Q&A']);
    });

    test('passes a label the app has and fails one it does not', () {
      const html = '<span class="ui">Save tutorial</span> then '
          '<span class="ui">Publish tutorial</span>';
      expect(missingLabels(html, literals), ['Publish tutorial']);
    });

    test('reads the source as the compiler does, not as text', () {
      const src = '''
// A comment quoting 'Ghost label' is not a label.
/* Nor is 'Block ghost' here. */
final a = Text('Save tutorial'); // and not 'Trailing ghost'
final b = 'Resume session \${session.roomCode}';
final c = "It's here";
final d = 'A long sentence '
    'written across lines.';
final e = 'https://chesstrainers.app/mislisha/manual/';
final f = 'Hello \$name';
final g = '\${x ? 'inner' : 'other'} tail';
''';
      final found = literalsIn(src);
      expect(
          found,
          containsAll([
            'Save tutorial',
            'Resume session',
            "It's here",
            'A long sentence written across lines.',
            'https://chesstrainers.app/mislisha/manual/',
            'Hello',
            'tail',
          ]));
      for (final ghost in ['Ghost label', 'Block ghost', 'Trailing ghost']) {
        expect(found.any((l) => l.contains(ghost)), isFalse, reason: ghost);
      }
    });

    test('finds the interpolated labels this app really draws', () {
      expect(_literalsOfLib(), contains('Resume session'),
          reason: 'the resume strip draws „Resume session \${code}"');
    });
  });
}
