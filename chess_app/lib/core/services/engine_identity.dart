import 'dart:io';

/// The name an engine binary's answers are kept under: its size and the
/// modification time of the file.
///
/// Phase 0 of `docs/PLAN-SKELET.md` showed the answers are a function of
/// exactly the binary — the same file gave byte-identical facts, and a
/// different build of Stockfish would not. Read by the tutorial's store, the
/// opening judge and `EvalCache`, so all three name one engine the same way.
Future<String> engineIdentity(String path) async {
  final stat = await File(path).stat();
  if (stat.type == FileSystemEntityType.notFound) {
    throw FileSystemException('The engine is not there', path);
  }
  return '${stat.size}-${stat.modified.toUtc().millisecondsSinceEpoch}';
}
