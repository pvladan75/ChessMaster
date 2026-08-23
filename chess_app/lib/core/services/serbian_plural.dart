/// Which form a Serbian noun takes after a number.
///
/// Serbian has three, not two, and the app was writing the third everywhere:
/// "Postoji još 2 takvih poteza" instead of "Postoje još 2 takva poteza". It
/// reads as a small thing and sounds like a large one - once the same sentence
/// is also being spoken aloud, a wrong case is the first thing a listener
/// notices.
///
///   1, 21, 31 …      jedan takav potez        (one)
///   2-4, 22-24 …     dva takva poteza         (few)
///   5-20, 25-30 …    pet takvih poteza        (many)
///
/// The exception that catches everyone: 11 to 14 take the last form even
/// though they end in 1 to 4.
library;

/// Which of the three forms [n] takes.
enum SerbianCount { one, few, many }

SerbianCount serbianCountForm(int n) {
  final abs = n.abs();
  final lastTwo = abs % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return SerbianCount.many;
  final last = abs % 10;
  if (last == 1) return SerbianCount.one;
  if (last >= 2 && last <= 4) return SerbianCount.few;
  return SerbianCount.many;
}

/// Picks the wording that fits [n].
///
/// The caller writes all three out in full, numeral included, rather than
/// handing over a stem to be glued together. Serbian inflects the adjective and
/// often the verb too - "Postoji jedan" against "Postoje dva" - so there is no
/// suffix to swap, and a sentence written whole is a sentence someone can read
/// and check.
///
/// Write the number as a numeral, not as a word: [one] is also the form for 21
/// and 31, where "jedan" would be wrong.
String serbianCount(
  int n, {
  required String one,
  required String few,
  required String many,
}) {
  switch (serbianCountForm(n)) {
    case SerbianCount.one:
      return one;
    case SerbianCount.few:
      return few;
    case SerbianCount.many:
      return many;
  }
}
