import 'package:audioplayers/audioplayers.dart';

/// Playing a take back on this device, as the recording screen needs it.
///
/// An interface so the screen's tests never create a platform player: the
/// board following the audio is decided by `NarrationTake.beatAt`, and what is
/// worth testing is that the screen asks it, not that `audioplayers` plays.
abstract class NarrationPlayer {
  /// Where playback is, a few times a second.
  Stream<Duration> get positions;

  /// Once, when the audio has played to its end.
  Stream<void> get completed;

  Future<void> play(String path);
  Future<void> stop();
  Future<void> dispose();
}

/// The real one — the same package `replay_player_screen.dart` plays a room's
/// recording with.
class AudioplayersNarrationPlayer implements NarrationPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<Duration> get positions => _player.onPositionChanged;

  @override
  Stream<void> get completed => _player.onPlayerComplete;

  @override
  Future<void> play(String path) => _player.play(DeviceFileSource(path));

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
