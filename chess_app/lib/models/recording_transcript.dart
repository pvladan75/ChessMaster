/// The transcript of a recording's sound — phase 7 of `docs/PLAN-PRIPREMA.md`.
///
/// The server's shape (`GET /recordings/:id/transcript`,
/// `chess_backend/routes/recordingTranscript.js`): `language`, `vendor`,
/// `model`, `durationMs` and `sentences`, each a `startMs`, `endMs`, `text`
/// (what stands, corrected or not) and `heard` (what the vendor answered,
/// never edited). A sentence is `corrected` when the two differ.
class TranscriptSentence {
  const TranscriptSentence({
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.heard,
  });

  final int startMs;
  final int endMs;

  /// What is shown and sent — the trainer's correction, or the vendor's own
  /// answer when nobody has touched it.
  final String text;

  /// What the vendor answered. Never written to; a correction changes [text]
  /// alone, so this stays the thing being corrected *against*.
  final String heard;

  /// Whether a trainer has changed this sentence's words.
  bool get corrected => text != heard;

  factory TranscriptSentence.fromJson(Map<String, Object?> json) {
    return TranscriptSentence(
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      heard: json['heard'] as String? ?? '',
    );
  }
}

class RecordingTranscript {
  const RecordingTranscript({
    required this.language,
    required this.vendor,
    required this.model,
    required this.durationMs,
    required this.sentences,
    this.updatedAt,
  });

  final String language;
  final String vendor;
  final String model;
  final int durationMs;
  final List<TranscriptSentence> sentences;
  final DateTime? updatedAt;

  factory RecordingTranscript.fromJson(Map<String, Object?> json) {
    final rawSentences = json['sentences'];
    final updated = json['updatedAt'];
    return RecordingTranscript(
      language: json['language'] as String? ?? '',
      vendor: json['vendor'] as String? ?? '',
      model: json['model'] as String? ?? '',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      sentences: rawSentences is List
          ? [
              for (final s in rawSentences)
                if (s is Map)
                  TranscriptSentence.fromJson(Map<String, Object?>.from(s))
            ]
          : const [],
      updatedAt: updated is String ? DateTime.tryParse(updated) : null,
    );
  }
}

/// Which sentence is being said at [ms] — the last one whose start has
/// passed, or null before the first. The panel and nothing else asks this: it
/// is the one rule for "which sentence is current", read fresh from wherever
/// the player stands rather than tracked as its own piece of state.
int? sentenceAt(List<TranscriptSentence> sentences, int ms) {
  int? found;
  for (var i = 0; i < sentences.length; i++) {
    if (sentences[i].startMs <= ms) {
      found = i;
    }
  }
  return found;
}
