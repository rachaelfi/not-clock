import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Plays the sound when a countdown timer reaches zero.
///
/// Separate from AudioService on purpose: timer sounds live in
/// assets/sounds/timers/ and have their own looping and cutoff rules, and a
/// timer finishing shouldn't interfere with an alarm that's already ringing.
///
/// One shared player, so several timers finishing at once produce one sound
/// rather than a pile-up.
class TimerSoundService {
  static final AudioPlayer _player = AudioPlayer();
  static Timer? _cutoff;

  /// The sounds are short — timer.mp3 is about six seconds — so they loop.
  /// Without a cap, a timer nobody cancels would ring until the battery died.
  static const Duration maxRingTime = Duration(seconds: 90);

  static bool get isPlaying => _cutoff != null;

  /// Starts [filename] from assets/sounds/timers/, looping until [stop] is
  /// called or [maxRingTime] elapses.
  static Future<void> play(String filename) async {
    if (filename.isEmpty || filename == 'None') return;

    await stop(); // never stack two loops

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      // AssetSource is relative to assets/, so no leading "assets/" here.
      await _player.play(AssetSource('sounds/timers/$filename'));
      _cutoff = Timer(maxRingTime, stop);
    } catch (_) {
      // Missing file or unsupported format — the timer still shows DONE.
      _cutoff = null;
    }
  }

  static Future<void> stop() async {
    _cutoff?.cancel();
    _cutoff = null;
    try {
      await _player.stop();
    } catch (_) {
      // Nothing was playing.
    }
  }
}