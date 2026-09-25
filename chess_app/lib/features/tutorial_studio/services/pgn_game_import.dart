/// A PGN becomes a tutorial: phase 1 of `docs/PLAN-PGN-TUTORIJAL.md`.
///
/// Point 1 of the owner's note of 12.9.2026 — „možemo li obezbediti da se ovakvi
/// pgn-ovi pretvore u Tutorijale u samoj aplikaciji". Until now the only PGN a
/// tutorial could be built from was one replayed move by move on the studio's
/// board, or one pasted into the „PGN" tab a part at a time.
///
/// **Nothing here parses a move.** The line is read by `readStepTree` →
/// `LessonStepLine` → `MoveTree.parsePgn`, the child's own parser, and judged by
/// `problemsWithStep`, which is what the JSON import already judges a file with.
/// What this file adds is the two questions that reader cannot ask: *where does
/// one game end and the next begin*, and *what should the tutorial be called*.
///
/// **One game is one part — one line.** An annotated game is one continuous
/// line and the viewer already narrates it move by move, each comment a beat;
/// cutting it at every comment would make a transcript with a page-turn
/// between every sentence. Its side lines are the exception: the film walks
/// first children, so each variation is made a part of its own, in the order
/// of D2 of `docs/PLAN-MAPA-DELOVA.md` (`splitStepAtForks`).
///
/// **The movetext is kept as it came.** It is not re-exported: a round trip
/// through `PgnExporterService` stamps a fresh `[Date]` and rewrites spacing, so
/// the text a trainer recognises would come back subtly different for no reason.
/// The same rule a section already follows when it is saved untouched.
library;

import 'package:chess_app/features/lessons/models/part_titles.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/move_tree.dart';

/// The standard opening position, for a game whose text says nothing about
/// where it starts.
///
/// „A game with no header is a game from the standard opening position" — the
/// rule the app already applies to a pasted line, 8.9.2026.
const String standardStartFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// The header-line pattern, and the one thing this file reads a PGN's *text*
/// for. `[%cal ...]` inside a comment is deliberately not a header: the second
/// character rules it out.
final RegExp _headerLine = RegExp(r'^\s*\[[^%][^\]]*\]\s*$', multiLine: true);

final RegExp _headerValue = RegExp(r'^\s*\[(\w+)\s+"(.*)"\]\s*$');

/// Names this app stamps on every export, which therefore name nothing.
///
/// `PgnExporterService` writes „Player" against „Analysis Engine" whatever is on
/// the board, so a title built from them would read the same for every game a
/// trainer ever imported.
const Set<String> _anonymousNames = {
  '',
  '?',
  'player',
  'opponent',
  'analysis engine',
};

/// Every game in [text], as its own PGN.
///
/// The boundary is a blank line followed by a `[Event` — which is what
/// `chess_backend/services/gameArchiveImport.js` already splits a database on.
/// One rule, two readers, rather than two rules.
///
/// Text in front of the first header (a mail, a question, an explanation) is
/// dropped. A text with no header at all is one game, because a bare movetext is
/// the commonest thing anybody pastes.
List<String> pgnGamesOf(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  final firstHeader = trimmed.indexOf('[Event ');
  if (firstHeader < 0) return [trimmed];

  return trimmed
      .substring(firstHeader)
      .split(RegExp(r'\n\s*\n(?=\[Event )'))
      .map((game) => game.trim())
      .where((game) => game.isNotEmpty)
      .toList();
}

/// One game's headers, as they were written.
Map<String, String> headersOf(String pgn) {
  final out = <String, String>{};
  for (final line in pgn.split('\n')) {
    final match = _headerValue.firstMatch(line);
    if (match != null) out[match.group(1)!] = match.group(2)!;
  }
  return out;
}

/// The moves of [pgn] with the header block taken off, ending the way the
/// format contract asks: a space and a `*`.
String moveTextOf(String pgn) {
  final body = pgn.replaceAll(_headerLine, '').trim();
  if (body.isEmpty) return '';
  // Rule 13 of `docs/PGN-TUTORIAL-FORMAT.md`. A result that is already there is
  // left alone — `MoveTree.parsePgn` sweeps every result token out either way,
  // and rewriting `1-0` as `*` would tell a reader the game was unfinished.
  if (RegExp(r'(1-0|0-1|1/2-1/2|\*)$').hasMatch(body)) return body;
  return '$body *';
}

/// What to call the tutorial this game becomes.
///
/// The players, when the file says who they were; the file's own name when it
/// does not. Never „Analysis Studio Session", which is what this app stamps on
/// an export and says nothing about the game inside it.
String titleOf(String pgn, {String? fileName, int? gameNumber}) {
  final headers = headersOf(pgn);
  final white = (headers['White'] ?? '').trim();
  final black = (headers['Black'] ?? '').trim();

  // **One named side is enough.** „pvladan - Opponent" says which game this is;
  // the file name does not. Only when neither side says anything — „Player"
  // against „Analysis Engine", or two question marks — is there nothing here to
  // build a title out of.
  final named = !_anonymousNames.contains(white.toLowerCase()) ||
      !_anonymousNames.contains(black.toLowerCase());
  if (named) {
    final date = (headers['Date'] ?? '').replaceAll('?', '').trim();
    final when = date.isEmpty || date == '..' ? '' : ' ($date)';
    String side(String name) => name.isEmpty ? '?' : name;
    return '${side(white)} - ${side(black)}$when';
  }

  final fromFile = titleFromFileName(fileName);
  // One file can hold four hundred games, and four hundred rows with one name
  // between them is a list nobody can use.
  return gameNumber == null ? fromFile : '$fromFile $gameNumber';
}

/// One game, read into the shape the rest of the app already takes.
///
/// The result is an [ImportedTutorial] exactly as `readTutorialJson` builds one,
/// so the pre-flight report, the studio's banner, the save path and
/// `chess_app/tool/grade_tutorial.dart` all work on it with no change at all.
ImportedTutorial tutorialFromGame(
  String pgn, {
  String? fileName,
  int? gameNumber,
  List<String> tags = const [],
}) {
  final moves = moveTextOf(pgn);
  if (moves.isEmpty) {
    return ImportedTutorial.unreadable(
      'There are no moves in this game.',
      fileName: fileName,
    );
  }

  final fen = MoveTree.fenHeaderOf(pgn) ?? standardStartFen;
  final step = <String, dynamic>{
    'title': generatedSectionTitle(0),
    'fen': fen,
    'kind': 'show',
    'pgn': moves,
  };
  final steps = splitStepAtForks(step);

  return ImportedTutorial(
    title: titleOf(pgn, fileName: fileName, gameNumber: gameNumber),
    description: null,
    tags: tags,
    // Not said. A PGN carries no language, and guessing one from a trainer's
    // sentences is how a tutorial comes to be read aloud in the wrong voice;
    // `LanguageWrite.unsaid` is the third answer this app already has for it.
    language: null,
    positionList: steps,
    // The one reader, asked the one question it can answer: does this line
    // replay from this position? A game that does not is reported and still
    // opened, because a trainer can see what is wrong with it far better than
    // this can.
    problems: [
      for (var i = 0; i < steps.length; i++)
        ...problemsWithStep(steps[i], partNumber: i + 1),
    ],
    fileName: fileName,
  );
}

/// Every game in [text], each as its own tutorial.
///
/// One game to one tutorial is the default because that is what a trainer means
/// by „import my games"; putting four hundred games in one tutorial makes one
/// row nobody can open. A file that holds a single game answers with a single
/// tutorial whose title is not numbered.
List<ImportedTutorial> tutorialsFromPgn(
  String text, {
  String? fileName,
  List<String> tags = const [],
  int maxGames = maxGamesPerFile,
}) {
  final games = pgnGamesOf(text);
  if (games.isEmpty) {
    return [
      ImportedTutorial.unreadable('The file holds no PGN.', fileName: fileName)
    ];
  }

  final kept = games.take(maxGames).toList();
  final out = [
    for (var i = 0; i < kept.length; i++)
      tutorialFromGame(
        kept[i],
        fileName: fileName,
        gameNumber: games.length == 1 ? null : i + 1,
        tags: tags,
      ),
  ];

  if (games.length > kept.length) {
    // Said rather than silently done. A database export is an ordinary thing to
    // pick by mistake — the owner's own Lichess file holds 4126 games — and
    // reading it whole would make four thousand rows in the report and four
    // thousand rows in the library. A cut nobody is told about is the fault
    // this repository keeps finding; this one is a sentence on the first row.
    out[0] = ImportedTutorial(
      title: out[0].title,
      description: out[0].description,
      tags: out[0].tags,
      language: out[0].language,
      positionList: out[0].positionList,
      fileName: out[0].fileName,
      problems: [
        ImportProblem(
          fault: ImportFault.damaged,
          message: 'this file holds ${games.length} games and the first '
              '${kept.length} were read. Split it if you need the rest.',
        ),
        ...out[0].problems,
      ],
    );
  }
  return out;
}

/// How many games one file may become.
///
/// A whole database is an ordinary thing to pick by mistake: a Lichess export
/// of one account's games runs to thousands, and one tutorial per game is the
/// rule everywhere else here.
const int maxGamesPerFile = 50;

/// One picked file, read by whichever reader it asks for.
///
/// **`.json` is taken at its word; everything else is decided by its content.**
/// A tutorial file is a JSON object and therefore starts with `{`, and a PGN
/// never does — so a file named `.pgn` that holds JSON is somebody's rename and
/// is read as the tutorial it is.
///
/// The extension has to win for `.json`, and the existing import tests are what
/// said so: a trainer who picks `broken.json` and gets „there are no moves in
/// this game" has been told about the wrong reader. „The file is not valid
/// JSON" is the sentence that names what they did.
/// The labels a trainer chose are **not** applied here: the import dialog puts
/// them on the whole batch at the end, through `withLabels`, and doing it twice
/// in two places is how one of them comes to be forgotten.
List<ImportedTutorial> tutorialsFromFile({
  required String name,
  required String text,
}) {
  if (name.toLowerCase().endsWith('.json') || text.trimLeft().startsWith('{')) {
    return [readTutorialJson(text, fileName: name)];
  }
  return tutorialsFromPgn(text, fileName: name);
}
