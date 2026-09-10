import 'package:flutter/material.dart';
import 'package:not_clock/main.dart';
import 'package:not_clock/models/alarm_data.dart';
import 'package:not_clock/config/sound_config.dart';
import 'package:not_clock/services/audio_service.dart';
import 'package:not_clock/theme/app_theme.dart';

/// Sound picker screen that shows available sounds from asset files.
///
/// [soundType] controls which sound list to show:
/// - 'alarms' shows sounds from assets/sounds/alarms/
/// - 'timers' shows sounds from assets/sounds/timers/
///
/// Returns the selected filename (e.g. 'birds.mp3') or 'None'.
class SoundPickerScreen extends StatefulWidget {
  final String selectedSound;
  final String soundType; // 'alarms' or 'timers'

  const SoundPickerScreen({
    super.key,
    required this.selectedSound,
    this.soundType = 'alarms',
  });

  @override
  State<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends State<SoundPickerScreen> {
  late String _selected;

  // Custom sounds uploaded by the user (stored as filenames/paths)
  // TODO: Persist this list to disk so custom sounds survive app restart.
  // You could save these paths in StorageService or a separate JSON file.
  final List<String> _customSounds = [];

  /// Get the right built-in sound list based on type
  List<String> get _sounds =>
      widget.soundType == 'timers' ? timerSounds : alarmSounds;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedSound;
  }

  @override
  void dispose() {
    // Stop any preview that's playing when leaving the screen
    AudioService.stopPreview();
    super.dispose();
  }

  /// Upload a custom sound file from the device.
  ///
  /// TODO: To implement this fully, add the `file_picker` package:
  ///   1. Add to pubspec.yaml: file_picker: ^8.0.0
  ///   2. Import: import 'package:file_picker/file_picker.dart';
  ///   3. Replace the dialog below with:
  ///
  ///   void _uploadCustomSound() async {
  ///     final result = await FilePicker.platform.pickFiles(
  ///       type: FileType.custom,
  ///       allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg'],
  ///     );
  ///     if (result != null && result.files.single.path != null) {
  ///       final filePath = result.files.single.path!;
  ///       final fileName = result.files.single.name;
  ///       // Copy file to app's documents directory for persistence
  ///       // Then add to _customSounds and select it
  ///       setState(() {
  ///         _customSounds.add(fileName);
  ///         _selected = fileName;
  ///       });
  ///     }
  ///   }
  ///
  /// For now, this shows a placeholder dialog that simulates adding a sound.
  void _uploadCustomSound() {
    final c = SettingsProvider.read(context).colors;
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: c.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Custom Sound',
              style: TextStyle(color: c.text, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'In a full build, this would open a file picker to select '
                'audio files (.mp3, .wav, .m4a) from your device.\n\n'
                'To implement: add the file_picker package and follow '
                'the TODO in sound_picker.dart.',
                style: TextStyle(color: c.subtext, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: c.text),
                cursorColor: c.accent,
                decoration: InputDecoration(
                  hintText: 'Sound name (placeholder)',
                  hintStyle: TextStyle(color: c.muted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.accentWash(0.3)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.accent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: c.subtext)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _customSounds.add(controller.text);
                    _selected = controller.text;
                  });
                }
                Navigator.pop(ctx);
              },
              child: Text('Add', style: TextStyle(color: c.accent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SettingsProvider.of(context).colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context, _selected),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios, color: c.accentSoft, size: 20),
          ),
        ),
        title: Text('Sound',
            style: TextStyle(
                color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Upload custom sound button ──
          GestureDetector(
            onTap: _uploadCustomSound,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: c.accentWash(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.accentWash(0.3), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: c.accentSoft, size: 20),
                  const SizedBox(width: 8),
                  Text('Upload Custom Sound',
                      style: TextStyle(
                          color: c.accentSoft,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          // ── Custom sounds section (user-uploaded) ──
          if (_customSounds.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('MY SOUNDS',
                  style: TextStyle(
                      color: c.subtext,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2)),
            ),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customSounds.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Divider(color: c.divider, height: 1),
                ),
                itemBuilder: (context, index) {
                  return _soundTile(c, _customSounds[index], isCustom: true);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Built-in sounds from assets ──
          if (_sounds.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                widget.soundType == 'timers'
                    ? 'TIMER SOUNDS'
                    : 'ALARM SOUNDS',
                style: TextStyle(
                    color: c.subtext,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sounds.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Divider(color: c.divider, height: 1),
                ),
                itemBuilder: (context, index) {
                  return _soundTile(c, _sounds[index]);
                },
              ),
            ),
          ],

          // Show message if no built-in sounds configured
          if (_sounds.isEmpty && _customSounds.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.music_off, color: c.muted, size: 40),
                  const SizedBox(height: 12),
                  Text('No sounds added yet',
                      style: TextStyle(color: c.subtext, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    'Add MP3 files to assets/sounds/ and\n'
                    'list them in lib/config/sound_config.dart\n'
                    'or tap "Upload Custom Sound" above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                ],
              ),
            ),

          // ── None option — always available ──
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _soundTile(c, 'None'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Builds a single sound tile row.
  /// [isCustom] marks whether this is a user-uploaded sound (for future use
  /// when you need different preview logic for custom vs asset sounds).
  Widget _soundTile(AppColors c, String filenameOrNone,
      {bool isCustom = false}) {
    final isNone = filenameOrNone == 'None';
    final isSelected = _selected == filenameOrNone;
    // Show a pretty display name instead of the raw filename
    final displayName =
        isNone ? 'None' : soundDisplayName(filenameOrNone);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selected = filenameOrNone);
        // Play a preview of the sound when tapped (not for 'None')
        if (!isNone && !isCustom) {
          // Preview from assets
          AudioService.previewSound(widget.soundType, filenameOrNone);
        } else if (!isNone && isCustom) {
          // TODO: Preview custom sounds from file path
          // AudioService.previewCustomSound(filenameOrNone);
        } else {
          AudioService.stopPreview();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                isNone
                    ? Icons.volume_off
                    : isCustom
                        ? Icons.folder_open
                        : isSelected
                            ? Icons.volume_up
                            : Icons.music_note,
                color: isSelected ? c.accentSoft : c.muted,
                size: 18,
              ),
            ),
            // Sound name
            Expanded(
              child: Text(displayName,
                  style: TextStyle(
                    color: isSelected ? c.accentSoft : c.text,
                    fontSize: 16,
                  )),
            ),
            // Checkmark for selected
            if (isSelected)
              Icon(Icons.check, color: c.accent, size: 20),
          ],
        ),
      ),
    );
  }
}