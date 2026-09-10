/// The trainer's own voice on a tutorial — phase 1 of `docs/PLAN-SNIMANJE.md`,
/// the pure core.
///
/// **A marker is the recorder's position, never `DateTime.now()`.** Phase 0
/// measured why on both targets: the microphone's warm-up is 750 ms on one
/// Android phone and 668 ms then 100 ms on one Windows machine minutes apart,
/// and a single three-second pause puts a wall clock 2.6 to 3.1 seconds ahead
/// of the audio for the rest of the take. `record` 7.1.1 exposes no position
/// at all, so the position is counted: `startStream` hands out raw 16-bit PCM,
/// and bytes ÷ byte rate is the audio's own clock. `ffprobe` agreed with that
/// count to the millisecond three times out of three.
///
/// So nothing in this file reads a clock to place a beat. [NarrationRecorder]
/// is driven by the chunks the microphone delivers, and the only time it knows
/// is how much audio it has been handed.
///
/// Deliberately knows nothing about the plugin, the file system's layout or a
/// widget — `RecordPcmSource` is the plugin, [NarrationTakeStore] the layout,
/// and the recording screen the widget. That is what makes the arithmetic
/// testable, which is the whole reason `LessonRecorder` was extracted from the
/// room before it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// 16 kHz mono: speech needs nothing more, and a twenty-minute take is 38 MB of
/// wav on the device rather than four times that.
const int narrationSampleRate = 16000;
const int narrationChannels = 1;
const int _bytesPerSample = 2; // AudioEncoder.pcm16bits

/// Bytes of audio per second of it.
const int narrationByteRate =
    narrationSampleRate * narrationChannels * _bytesPerSample;

/// Where the byte clock says a take is, in milliseconds.
int audioMsOf(int bytes) => (bytes * 1000) ~/ narrationByteRate;

/// The quietest 16-bit audio can be: one step of the smallest sample. A chunk
/// of exact zeros is reported as this rather than as minus infinity.
const double silenceFloorDbfs = -96.0;

/// Above this, a microphone is live; at or below it, nothing is reaching it.
///
/// **A threshold for a dead microphone, not for speech.** The Windows spike
/// recorded a muted microphone as −91 dB from end to end, with a flawless byte
/// clock, a correct wav header and nothing anywhere saying so. A live one in a
/// quiet room has a noise floor well above −70 even between sentences — no
/// noise suppression is asked for — so this only fires when the audio is not
/// there at all, and a trainer pausing to think is never told they are silent.
const double liveMicrophoneDbfs = -70.0;

/// The longest recording the server accepts — fifteen minutes,
/// `NARRATION_MAX_SECONDS` in `chess_backend/services/narrationUpload.js`,
/// which says why: the film is still drawn inside the export request.
const int narrationMaxMs = 15 * 60 * 1000;

/// Where a take is stopped so that it still fits: one second before the cap.
///
/// Audio arrives in whole chunks — 80 ms on Android, and nobody has measured
/// the largest a Windows device hands over — so a take stopped *at* the cap can
/// end a chunk past it and be refused by a server counting to the millisecond.
/// A second is several chunks of margin and costs the trainer nothing.
const int narrationStopAtMs = narrationMaxMs - 1000;

/// „1:07" — a take's length, or where it is. Here rather than on the screen
/// because the export dialog says it too.
String narrationClockOf(int ms) {
  final seconds = ms ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// The loudest sample in [pcm], in dBFS.
double peakDbfsOf(Uint8List pcm) {
  final data = ByteData.sublistView(pcm);
  var peak = 0;
  for (var i = 0; i + 1 < pcm.length; i += 2) {
    final sample = data.getInt16(i, Endian.little).abs();
    if (sample > peak) peak = sample;
  }
  if (peak == 0) return silenceFloorDbfs;
  final db = 20 * math.log(peak / 32768) / math.ln10;
  return math.max(db, silenceFloorDbfs);
}

/// A finished take: where each beat of the film begins in the audio.
///
/// [markersMs] is indexed by the film's event index — `filmBeatsOf` and
/// `tutorialVideoOf` walk one projection, so index `i` here is event `i` there.
/// The first marker is always 0: the audio's zero is its first sample, and the
/// film opens on beat 0.
class NarrationTake {
  NarrationTake({
    required List<int> markersMs,
    required this.durationMs,
    required this.eventCount,
    required this.peakDbfs,
    required this.recordedAt,
    this.signature,
  }) : markersMs = List.unmodifiable(markersMs);

  final List<int> markersMs;

  /// The audio's own length, from the same byte count as the markers.
  final int durationMs;

  /// How many events the film had when this was recorded. A take with fewer
  /// markers than this stopped part-way through.
  final int eventCount;

  /// The loudest moment of the whole take.
  final double peakDbfs;

  /// When it was recorded. Metadata for a sentence on screen and nothing more:
  /// no marker is ever derived from a clock.
  final DateTime recordedAt;

  /// `filmSignatureOf` over the beats this was recorded against — phase 5.
  ///
  /// **Null is „this take never carried one", not „it matches".** Takes
  /// recorded before phase 5 are on trainers' devices and on the server, and
  /// they are perfectly good recordings; they fall back to the beat count,
  /// which is what judged them before. Reading a missing signature as agreement
  /// would be the same mistake in the other direction — see [takeMismatchOf].
  final String? signature;

  /// Whether every beat of the film has a place in the audio.
  bool get isComplete => markersMs.length == eventCount;

  /// Whether the microphone was live at any point. A take that never was is
  /// silence with a working clock — exactly what the spike produced.
  bool get heardAnything => peakDbfs > liveMicrophoneDbfs;

  /// How long the last beat is spoken over. Zero when the take was stopped the
  /// instant the last beat came up, which a film would show as a flash.
  int get lastBeatMs => markersMs.isEmpty ? 0 : durationMs - markersMs.last;

  /// Which beat is on screen at [positionMs] into the audio — the last one
  /// whose marker has passed. Playback reads it; so will the film.
  int beatAt(int positionMs) {
    var lo = 0;
    var hi = markersMs.length - 1;
    if (hi < 0) return 0;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (markersMs[mid] <= positionMs) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  Map<String, dynamic> toJson() => {
        'markersMs': markersMs,
        'durationMs': durationMs,
        'eventCount': eventCount,
        'peakDbfs': peakDbfs,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        if (signature != null) 'signature': signature,
      };

  factory NarrationTake.fromJson(Map<String, dynamic> json) => NarrationTake(
        markersMs: [
          for (final m in json['markersMs'] as List) (m as num).toInt()
        ],
        durationMs: (json['durationMs'] as num).toInt(),
        eventCount: (json['eventCount'] as num).toInt(),
        peakDbfs: (json['peakDbfs'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String).toLocal(),
        signature: json['signature'] as String?,
      );
}

/// Why a take cannot be the voice of the film in front of it.
///
/// **One decision, read in three places**, which is the reason it is here and
/// not written out where it is shown: the recording screen says it about „this
/// recording", the export dialog about „your recording", and the server about
/// the one it holds. Three sentences are fine — three answers to „is this take
/// still the right one" is how the export comes to offer a switch the render
/// then refuses.
enum TakeMismatch {
  /// It can.
  none,

  /// Nothing ever reached the microphone: silence with a working clock, which
  /// is exactly what a muted input produces.
  silent,

  /// Recorded against a different number of beats — the commonest edit, and
  /// the one phase 1 could already see.
  beatsChanged,

  /// The same number of beats, saying something else: a sentence rewritten, a
  /// move replaced, a part reordered or opened on another position. This is
  /// what phase 5 exists for, and no count can see it.
  edited,

  /// Stopped part-way: the last beats have no place in the audio.
  incomplete,
}

/// Whether [take] can be the voice of a film of [beats] beats whose beat list
/// signs as [signature].
///
/// The order is what a trainer can act on: a silent take is worth saying before
/// anything about beats, because it is wrong whatever the tutorial says now.
///
/// **A take with no signature is judged by the count, as it was before phase
/// 5.** It is a real recording made by an earlier version of this app, and a
/// missing signature must not read as either answer to a question it was never
/// asked — refusing every one of them is a trainer told to re-record an hour
/// for nothing, and passing them all is the silent wrong film phase 5 exists to
/// prevent. The count still catches the commonest edit, which is what those
/// takes have always been judged by.
TakeMismatch takeMismatchOf(
  NarrationTake take, {
  required int beats,
  required String signature,
}) {
  if (!take.heardAnything) return TakeMismatch.silent;
  if (take.eventCount != beats) return TakeMismatch.beatsChanged;
  final signed = take.signature;
  if (signed != null && signed != signature) return TakeMismatch.edited;
  if (!take.isComplete) return TakeMismatch.incomplete;
  return TakeMismatch.none;
}

/// The microphone, as this file needs it. `RecordPcmSource` is the real one.
abstract class PcmSource {
  Future<bool> hasPermission();

  /// Starts delivering 16 kHz mono 16-bit little-endian PCM.
  Future<Stream<Uint8List>> start();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

/// Where the audio goes while it is recorded. [WavFileSink] is the real one.
abstract class NarrationSink {
  void add(Uint8List chunk);

  /// Completes the file. After this it is a wav any player can open.
  Future<void> finish();

  /// Throws the audio away.
  Future<void> discard();
}

enum NarrationState {
  /// Nothing asked of the microphone yet.
  idle,

  /// Asked, and no audio has arrived. Beat 0 is on screen, but the trainer is
  /// not being recorded yet, and a „Next" now would name a moment the audio
  /// does not contain.
  warmingUp,
  recording,
  paused,
  stopped,
}

enum NarrationStart { started, noPermission, busy }

enum NarrationNext {
  advanced,

  /// Not recording: before the first sample, or after stop.
  notListening,

  /// The last beat is already on screen.
  atEnd,

  /// The clock has not moved past the last marker — a key held down, a double
  /// press inside one chunk, or a second press inside one pause. Two beats at
  /// one moment would be one frame in the film, and the first would never be
  /// seen.
  clockHasNotMoved,
}

/// One take, from the first sample to stop.
///
/// Every byte the microphone hands over is written to [sink] **and** counted,
/// in the same place, so the file and the markers cannot disagree about how
/// long the audio is. That includes the one chunk Android delivers after a
/// pause is asked for: it is in the audio, so it is in the count.
class NarrationRecorder extends ChangeNotifier {
  NarrationRecorder({
    required this.source,
    required this.sink,
    required this.eventCount,
    this.signature,
  }) : assert(eventCount > 0);

  final PcmSource source;
  final NarrationSink sink;

  /// How many beats the film has. The take is complete when each has a marker.
  final int eventCount;

  /// What the beat list said when this take was started — `filmSignatureOf`.
  /// Stamped on the take at [stop], and read back by [takeMismatchOf].
  final String? signature;

  NarrationState _state = NarrationState.idle;
  StreamSubscription<Uint8List>? _subscription;
  final List<int> _markers = [];
  int _bytes = 0;
  int _liveAtBytes = 0;
  double _peak = silenceFloorDbfs;

  NarrationState get state => _state;

  /// The beat on screen. Beat 0 from the moment recording is asked for.
  int get beat => _markers.isEmpty ? 0 : _markers.length - 1;

  /// The markers so far, one per beat reached.
  List<int> get markersMs => List.unmodifiable(_markers);

  /// How far into the audio the take is, by its own clock.
  int get positionMs => audioMsOf(_bytes);

  /// Whether the microphone has been live at any point in this take.
  bool get heardAnything => _peak > liveMicrophoneDbfs;

  /// Audio since the microphone was last live — the whole take, if it never
  /// was. Measured in audio, so a pause does not count as silence.
  int get silentMs => audioMsOf(_bytes - _liveAtBytes);

  bool get isLastBeat => beat >= eventCount - 1;

  Future<NarrationStart> start() async {
    if (_state != NarrationState.idle) return NarrationStart.busy;
    if (!await source.hasPermission()) {
      // The sink already made its file; a refusal must not leave it behind.
      await sink.discard();
      return NarrationStart.noPermission;
    }

    _state = NarrationState.warmingUp;
    notifyListeners();
    try {
      final stream = await source.start();
      _subscription = stream.listen(_onChunk);
    } catch (_) {
      _state = NarrationState.idle;
      notifyListeners();
      await sink.discard();
      rethrow;
    }
    return NarrationStart.started;
  }

  // No check of the state here: nothing is listening before [start] or after
  // [stop] and [cancel], which cancel the subscription before anything else. A
  // second guard behind that one could never fire, and so could never be
  // proved.
  void _onChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;

    sink.add(chunk);
    // The first sample is the audio's zero, and beat 0 is what it is spoken
    // over — however long the microphone took to wake up.
    if (_markers.isEmpty) _markers.add(0);
    _bytes += chunk.length;

    final level = peakDbfsOf(chunk);
    if (level > _peak) _peak = level;
    if (level > liveMicrophoneDbfs) _liveAtBytes = _bytes;

    if (_state == NarrationState.warmingUp) _state = NarrationState.recording;
    notifyListeners();
  }

  /// Puts the next beat on screen, at this point in the audio.
  ///
  /// **Allowed while paused**, once. A pause leaves no gap in the audio, so a
  /// beat advanced during one lands exactly on the seam, and the trainer
  /// resumes talking about the position that is now in front of them.
  NarrationNext next() {
    if (_state != NarrationState.recording && _state != NarrationState.paused) {
      return NarrationNext.notListening;
    }
    if (isLastBeat) return NarrationNext.atEnd;
    final at = positionMs;
    if (at <= _markers.last) return NarrationNext.clockHasNotMoved;
    _markers.add(at);
    notifyListeners();
    return NarrationNext.advanced;
  }

  /// Stops the microphone, and with it the clock: no audio, no time.
  Future<void> pause() async {
    if (_state != NarrationState.recording) return;
    await source.pause();
    _state = NarrationState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_state != NarrationState.paused) return;
    await source.resume();
    _state = NarrationState.recording;
    notifyListeners();
  }

  /// Ends the take and hands it over, or null when no audio ever arrived — a
  /// take with no first sample has no zero to measure anything from.
  Future<NarrationTake?> stop() async {
    if (_state == NarrationState.idle || _state == NarrationState.stopped) {
      return null;
    }
    // The subscription goes before the microphone: from the moment it is
    // cancelled nothing more is delivered, so a chunk still in flight is
    // neither written nor counted — the file and the clock stay one number.
    //
    // Not awaited. The cancel takes effect when it is called; the future it
    // returns is already complete in the root zone, and under a widget test's
    // fake clock awaiting it never resumes — which hung Stop and Discard.
    _state = NarrationState.stopped;
    unawaited(_subscription?.cancel());
    _subscription = null;
    await source.stop();

    if (_markers.isEmpty) {
      await sink.discard();
      notifyListeners();
      return null;
    }

    await sink.finish();
    notifyListeners();
    return NarrationTake(
      markersMs: _markers,
      durationMs: positionMs,
      eventCount: eventCount,
      peakDbfs: _peak,
      recordedAt: DateTime.now(),
      signature: signature,
    );
  }

  /// Throws the take away.
  Future<void> cancel() async {
    if (_state == NarrationState.idle || _state == NarrationState.stopped) {
      return;
    }
    _state = NarrationState.stopped;
    unawaited(_subscription?.cancel()); // see stop()
    _subscription = null;
    await source.stop();
    await sink.discard();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    source.dispose();
    super.dispose();
  }
}

/// The 44-byte header of a 16 kHz mono 16-bit wav holding [dataLength] bytes.
Uint8List wavHeaderOf(int dataLength) {
  final header = ByteData(44);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, narrationChannels, Endian.little);
  header.setUint32(24, narrationSampleRate, Endian.little);
  header.setUint32(28, narrationByteRate, Endian.little);
  header.setUint16(32, narrationChannels * _bytesPerSample, Endian.little);
  header.setUint16(34, 8 * _bytesPerSample, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, dataLength, Endian.little);
  return header.buffer.asUint8List();
}

/// The number of audio bytes a wav header says follow it, or null when [header]
/// is not one of ours.
int? wavDataLengthOf(Uint8List header) {
  if (header.length < 44) return null;
  if (String.fromCharCodes(header.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(header.sublist(8, 12)) != 'WAVE' ||
      String.fromCharCodes(header.sublist(36, 40)) != 'data') {
    return null;
  }
  return ByteData.sublistView(header).getUint32(40, Endian.little);
}

/// A wav written as it is recorded, straight to disk.
///
/// Streamed rather than held, because a twenty-minute take is 38 MB. The
/// header is written first with no length in it and patched on [finish] — so a
/// file that was never finished says it holds nothing, which is the truth about
/// it, rather than claiming a length it does not have.
class WavFileSink implements NarrationSink {
  WavFileSink(this.path)
      : _file = (File(path)..parent.createSync(recursive: true))
            .openSync(mode: FileMode.write) {
    _file.writeFromSync(wavHeaderOf(0));
  }

  final String path;
  final RandomAccessFile _file;
  int _length = 0;
  bool _closed = false;

  @override
  void add(Uint8List chunk) {
    if (_closed) return;
    _file.writeFromSync(chunk);
    _length += chunk.length;
  }

  @override
  Future<void> finish() async {
    if (_closed) return;
    _closed = true;
    _file.setPositionSync(0);
    _file.writeFromSync(wavHeaderOf(_length));
    _file.closeSync();
  }

  @override
  Future<void> discard() async {
    if (!_closed) {
      _closed = true;
      _file.closeSync();
    }
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}

/// What a tutorial has on this device.
class StoredNarration {
  const StoredNarration({required this.take, required this.audioPath});
  final NarrationTake take;
  final String audioPath;

  /// The random part of `take-<id>.wav`. The server keeps it beside the
  /// recording, so the app can tell whether the take there is this one without
  /// sending it again.
  String? get takeId =>
      RegExp(r'take-([0-9a-f]+)\.wav$').firstMatch(audioPath)?.group(1);
}

/// The answer to „does this tutorial have a take here", which has three.
///
/// **Unreadable is not the same as none.** A trainer who recorded an hour and
/// finds the take gone has to be told it is gone, rather than meet a screen
/// that simply offers to record — that would be a lost recording reported as
/// success, the oldest shape in this repository.
class NarrationLoad {
  const NarrationLoad.none()
      : stored = null,
        unreadable = false;
  const NarrationLoad.found(StoredNarration this.stored) : unreadable = false;
  const NarrationLoad.unreadable()
      : stored = null,
        unreadable = true;

  final StoredNarration? stored;
  final bool unreadable;
}

/// Takes on this device, one per tutorial, under the app's support directory.
///
/// **Each take has its own name and the index names it.** A retake is recorded
/// beside the old one, `take.json` is replaced to point at it, and only then is
/// the old audio deleted — so a crash at any point leaves a `take.json` naming
/// a file that exists and matches it. The other order leaves new audio under
/// old markers, which is a film whose voice and board disagree from the first
/// beat and nothing to say why. Same rule the server follows for a tutorial's
/// film: the row is written before the old file goes.
class NarrationTakeStore {
  NarrationTakeStore(this._root);

  /// The directory every tutorial's folder lives in.
  final Future<Directory> Function() _root;

  static const _index = 'take.json';

  /// Only recording creates the folder. Looking for a take — which every
  /// export does — must not leave an empty folder behind for every tutorial
  /// that was ever exported.
  Future<Directory> _dirOf(int lessonId, {bool create = true}) async {
    final root = await _root();
    final dir =
        Directory('${root.path}${Platform.pathSeparator}lesson_$lessonId');
    if (create && !dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// A fresh path for a take about to be recorded. It ends in `.partial` until
  /// [keep] names it, so a take abandoned by a crash is never mistaken for one.
  ///
  /// Random rather than a clock: a clock is not a name.
  Future<String> newRecordingPath(int lessonId) async {
    final dir = await _dirOf(lessonId);
    final id = List.generate(
        4,
        (_) => math.Random()
            .nextInt(1 << 16)
            .toRadixString(16)
            .padLeft(4, '0')).join();
    return '${dir.path}${Platform.pathSeparator}take-$id.wav.partial';
  }

  /// Makes [take], recorded at [partialPath], this tutorial's take.
  Future<StoredNarration> keep(
      int lessonId, NarrationTake take, String partialPath) async {
    final dir = await _dirOf(lessonId);
    final sep = Platform.pathSeparator;
    final audioName = File(partialPath)
        .uri
        .pathSegments
        .last
        .replaceFirst(RegExp(r'\.partial$'), '');
    final audio = File(partialPath).renameSync('${dir.path}$sep$audioName');

    final index = File('${dir.path}$sep$_index');
    final pending = File('${index.path}.partial')
      ..writeAsStringSync(jsonEncode({'audio': audioName, ...take.toJson()}));
    pending.renameSync(index.path);

    // Only now, with the index naming the new one.
    for (final entry in dir.listSync()) {
      if (entry is File &&
          entry.path != audio.path &&
          entry.path.endsWith('.wav')) {
        entry.deleteSync();
      }
    }
    return StoredNarration(take: take, audioPath: audio.path);
  }

  /// This tutorial's take, checked against its own audio before it is trusted.
  Future<NarrationLoad> load(int lessonId) async {
    final dir = await _dirOf(lessonId, create: false);
    final sep = Platform.pathSeparator;
    final index = File('${dir.path}$sep$_index');
    if (!index.existsSync()) return const NarrationLoad.none();

    try {
      final json = jsonDecode(index.readAsStringSync()) as Map<String, dynamic>;
      final take = NarrationTake.fromJson(json);
      final audio = File('${dir.path}$sep${json['audio']}');

      // The writer's own work, read back: markers that describe a different
      // length of audio are markers for some other take. Audio that is gone
      // throws on open, and the catch below answers for it — a separate
      // existence check in front of this one could never be the one that fired.
      final header = Uint8List(44);
      final raf = audio.openSync();
      try {
        raf.readIntoSync(header);
      } finally {
        raf.closeSync();
      }
      final length = wavDataLengthOf(header);
      if (length == null || audioMsOf(length) != take.durationMs) {
        return const NarrationLoad.unreadable();
      }
      return NarrationLoad.found(
          StoredNarration(take: take, audioPath: audio.path));
    } catch (_) {
      return const NarrationLoad.unreadable();
    }
  }

  /// Deletes this tutorial's take. Only ever somebody's explicit act.
  Future<void> delete(int lessonId) async {
    final dir = await _dirOf(lessonId, create: false);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
