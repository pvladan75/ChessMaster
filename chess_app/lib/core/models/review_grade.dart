/// How well a position was recalled, on SM-2's 0–5 scale — the grades the
/// mistake drill sends (`chess_backend/services/spacedRepetitionService.js`
/// holds the same four).
///
/// Four buttons rather than six: asking somebody to distinguish six shades of
/// remembering produces noise, not data. Anything below 3 counts as a failure.
///
/// It lived beside the spaced repetition of a tutorial's parts, which went
/// with the parts (`docs/PLAN-TUTORIJAL-VIDEO.md`, D9).
enum ReviewGrade {
  again(1, 'Again'),
  hard(3, 'Hard'),
  good(4, 'Good'),
  easy(5, 'Easy');

  const ReviewGrade(this.quality, this.label);

  final int quality;
  final String label;
}
