/// Reads an integer that may arrive as a JSON number *or* as a JSON string.
///
/// `user_game_imports.id` is `BIGSERIAL`, and node-postgres hands `int8` back
/// as a string rather than a number — a 64-bit integer does not always survive
/// a double. So `importId` and a run's `id` reach us as `"123"`, while every
/// counter beside them (`INTEGER`) arrives as `123`. A plain `as int` cast
/// reads the two identically right up until it throws on real data, and the
/// fakes in the widget tests hand out real `int`s, so nothing here would have
/// caught it.
int jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Nije ceo broj: $value');
}
