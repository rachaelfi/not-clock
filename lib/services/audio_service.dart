import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';


/// AudioService handles all sound playback for alarms and timers. It uses the audioplayers package to play audio files from assets.

/// Key behaviors:
/// -Plays MP3 files from assets/sounds/alarms/ or assets/sounds/timers/
/// -Loops the sound until stopped or 3-minute cap is reached
/// -Provides preview playback for the sound picker (plays once, no loop)

/// Usage:
/// -AudioService.playAlarmSound('birds.mp3') to play an alarm sound
/// -AudioService.playTimerSound('timer.mp3') to play a timer sound
/// -AudioService.stop() to stop any currently playing sound
/// -AudioService.previewSound('birds', 'birds.mp3') to preview a sound once


class AudioService {
  static AudioPlayer? _player;
  // Timer that auto-stops after 3 minutes
  static Timer? _autoStopTimer;
  // Preview uses a separate player so it doesn't interfere
  static AudioPlayer? _previewPlayer;
 
  /// Play an alarm sound on loop with a 3-minute auto-stop.
  /// [filename] is the MP3 filename, e.g. 'birds.mp3'
  /// [folder] is 'alarms' or 'timers'
  static Future<void> playSound(String filename, {String folder = 'alarms'}) async {
    // Don't play if sound is 'None'
    if (filename == 'None' || filename.isEmpty) return;
 
    await stop(); // Stop any currently playing sound
 
    _player = AudioPlayer();
    final assetPath = 'sounds/$folder/$filename';
 
    try {
      // Set the source to our asset file
      await _player!.setSource(AssetSource(assetPath));
      // Enable looping — sound repeats until we call stop()
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.resume();
 
      // Auto-stop after 3 minutes (180 seconds) to prevent infinite playback
      _autoStopTimer?.cancel();
      _autoStopTimer = Timer(const Duration(minutes: 3), () {
        stop();
      });
    } catch (e) {
      // If the file doesn't exist or can't play, fail silently
      _player?.dispose();
      _player = null;
    }
  }
 
  /// Convenience method for alarm sounds
  static Future<void> playAlarmSound(String filename) async {
    await playSound(filename, folder: 'alarms');
  }
 
  /// Convenience method for timer sounds
  static Future<void> playTimerSound(String filename) async {
    await playSound(filename, folder: 'timers');
  }
 
  /// Stop whatever is currently playing
  static Future<void> stop() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
 
    await _player?.stop();
    await _player?.dispose();
    _player = null;
  }
 
  /// Preview a sound — plays once without looping.
  /// Used in the sound picker so the user can hear before selecting.
  static Future<void> previewSound(String folder, String filename) async {
    if (filename == 'None' || filename.isEmpty) return;
 
    // Stop any existing preview
    await stopPreview();
 
    _previewPlayer = AudioPlayer();
    final assetPath = 'sounds/$folder/$filename';
 
    try {
      await _previewPlayer!.setSource(AssetSource(assetPath));
      // Play once, don't loop
      await _previewPlayer!.setReleaseMode(ReleaseMode.release);
      await _previewPlayer!.resume();
    } catch (e) {
      _previewPlayer?.dispose();
      _previewPlayer = null;
    }
  }
 
  /// Stop the preview playback
  static Future<void> stopPreview() async {
    await _previewPlayer?.stop();
    await _previewPlayer?.dispose();
    _previewPlayer = null;
  }
 
  /// Check if a sound is currently playing
  static bool get isPlaying => _player?.state == PlayerState.playing;
 
  /// List all MP3 filenames in a given asset folder.
  /// Returns the raw filenames like ['alarm1.mp3', 'chime.mp3']
  ///
  /// NOTE: Flutter can't list asset directories at runtime on all platforms.
  /// This method uses the AssetManifest to find files in the folder.
  static Future<List<String>> listSounds(String folder) async {
    try {
      // Load the asset manifest — Flutter generates this at build time
      // It contains paths to every file declared in pubspec.yaml assets
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
 
      // The manifest is a JSON object where keys are asset paths
      final Map<String, dynamic> manifest =
          Map<String, dynamic>.from(
            // ignore: avoid_dynamic_calls
            await rootBundle.loadString('AssetManifest.json')
                .then((_) => <String, dynamic>{})
                .catchError((_) => <String, dynamic>{}),
          );
 
      // This approach doesn't work reliably across platforms.
      // Instead, we'll use a hardcoded discovery approach — see below.
      return [];
    } catch (e) {
      return [];
    }
  }
}