import 'package:flutter/material.dart';
import 'package:not_clock/models/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  final AppSettings settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Color(0xFFA29BFE), size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Use ListenableBuilder so the switch reflects changes immediately
              ListenableBuilder(
                listenable: settings,
                builder: (context, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF12121A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('24-Hour Time',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 16)),
                                SizedBox(height: 2),
                                Text('Display times in 24-hour format',
                                    style: TextStyle(
                                        color: Color(0xFF6A6A7A),
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          Switch(
                            value: settings.use24HourFormat,
                            onChanged: (val) {
                              settings.use24HourFormat = val;
                            },
                            activeColor: const Color(0xFF6C5CE7),
                            inactiveTrackColor: const Color(0xFF2A2A3A),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}