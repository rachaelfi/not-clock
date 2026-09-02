import 'package:flutter/material.dart';
import 'package:not_clock/models/alarm_data.dart';

class SoundPickerScreen extends StatefulWidget {
  final String selectedSound;
  final String? customSoundPath;

  const SoundPickerScreen({super.key, required this.selectedSound, this.customSoundPath});

  @override
  State<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends State<SoundPickerScreen> {
  late String _selected;
  final List<String> _customSounds = [];

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedSound;
  }

  void _uploadCustomSound() {
    // In a real app, use file_picker package to pick audio files.
    // For now, we simulate adding a custom sound.
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Custom Sound',
              style: TextStyle(color: Colors.white, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'In a full build, this would open a file picker to select audio files (.mp3, .wav, .m4a) from your device.',
                style: TextStyle(color: Color(0xFF8A85A0), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: const Color(0xFF6C5CE7),
                decoration: InputDecoration(
                  hintText: 'Sound name',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6C5CE7)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A85A0))),
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
              child: const Text('Add', style: TextStyle(color: Color(0xFF6C5CE7))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context, _selected),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios, color: Color(0xFFA29BFE), size: 20),
          ),
        ),
        title: const Text('Sound',
            style: TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Upload button
          GestureDetector(
            onTap: _uploadCustomSound,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      color: Color(0xFFA29BFE), size: 20),
                  SizedBox(width: 8),
                  Text('Upload Custom Sound',
                      style: TextStyle(
                          color: Color(0xFFA29BFE),
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),

          // Custom sounds section
          if (_customSounds.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('MY SOUNDS',
                  style: TextStyle(
                      color: Color(0xFF6A6A7A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2)),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF12121A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customSounds.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Divider(color: Color(0xFF1E1E2E), height: 1),
                ),
                itemBuilder: (context, index) {
                  final name = _customSounds[index];
                  return _soundTile(name);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Built-in sounds
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('RINGTONES',
                style: TextStyle(
                    color: Color(0xFF6A6A7A),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2)),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: builtInSounds.length,
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Divider(color: Color(0xFF1E1E2E), height: 1),
              ),
              itemBuilder: (context, index) {
                return _soundTile(builtInSounds[index]);
              },
            ),
          ),

          // None option
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _soundTile('None'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _soundTile(String name) {
    final isSelected = _selected == name;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selected = name);
        // In a real app, play the sound preview here
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(name,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFA29BFE) : Colors.white,
                    fontSize: 16,
                  )),
            ),
            if (isSelected)
              const Icon(Icons.check, color: Color(0xFF6C5CE7), size: 20),
          ],
        ),
      ),
    );
  }
}