/// Where a PGN leaves this app: one picker, one seam, two doors.
///
/// The Analysis studio's „Save as .pgn" (12.9.2026) was the first, and phase 4
/// of `docs/PLAN-PGN-TUTORIJAL.md` adds the second — a whole tutorial as a game
/// or several. Both write a file the same way, so the rule about *how* the
/// bytes are written lives here rather than once per dialog.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show Uint8List;

/// The one thing a widget test cannot do: open the operating system's save
/// dialog.
///
/// `FilePicker.saveFile` is a platform channel, and in a test nothing answers
/// it, so the button that waits for it waits for ever. A test sets this and
/// reads what it was handed, which is everything about saving except the file.
/// Same shape as `debugPlayVoiceSample`, and null in a real build.
Future<String?> Function({required String fileName, required String pgn})?
    debugSavePgnFile;

/// Hands [pgn] to the picker and answers with the path the trainer chose, or
/// null when they closed it.
///
/// The bytes are handed to the picker rather than written here: with `bytes`
/// given it writes them at the chosen path on every platform this app ships
/// to, and a second `File.writeAsBytes` beside that is how a file comes to be
/// written twice on one platform and not at all on another.
///
/// **UTF-8, deliberately.** `PgnExporterService` keeps its *headers* in ASCII
/// because the PGN standard is Latin-1 and a stricter reader shows „Š" as
/// rubbish — but a trainer's comments are their own words, and a sentence
/// mangled on the way out is worse than one a strict reader renders oddly.
Future<String?> savePgnFile(
        {required String fileName, required String pgn}) async =>
    FilePicker.saveFile(
      dialogTitle: 'Save PGN',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pgn'],
      bytes: Uint8List.fromList(utf8.encode(pgn)),
      lockParentWindow: true,
    );

/// `analysis-2026-09-12.pgn` — the date, because nothing else here has a name.
///
/// The export's own `[White]`/`[Black]` headers are „Player" and „Analysis
/// Engine" whatever is on the board, so a name built from them would say the
/// same thing for every file a trainer ever saved. A tutorial *does* have a
/// name; it is named by [tutorialPgnFileName] instead.
String pgnFileNameFor(DateTime day) =>
    'analysis-${day.year}-${_two(day.month)}-${_two(day.day)}.pgn';

/// What a tutorial's file is called: its own title, or the date when it has
/// none.
///
/// The title is a trainer's sentence and a file name is not — so the
/// characters Windows refuses (`\ / : * ? " < > |`) and any control character
/// are dropped, runs of whitespace become one hyphen, and the length is capped
/// well under the 255 a file system allows. Letters are **not** stripped of
/// their diacritics: the app writes UTF-8 file names everywhere else and
/// „opozicija-kraljem" losing its Serbian spelling would be a rename nobody
/// asked for.
String tutorialPgnFileName(String title, DateTime day) {
  final slug = title
      .trim()
      .replaceAll(RegExp(r'''[\/:*?"<>|\x00-\x1f]'''), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  if (slug.isEmpty) {
    return 'tutorial-${day.year}-${_two(day.month)}-${_two(day.day)}.pgn';
  }
  final short = slug.length <= 60 ? slug : slug.substring(0, 60);
  return '$short.pgn';
}

String _two(int n) => n.toString().padLeft(2, '0');
