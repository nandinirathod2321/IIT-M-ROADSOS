import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../crash_detection/crash_detector.dart';

/// Interactive Settings Screen for RoadSOS.
/// Provides configuration for Crash Detection, SOS settings, Emergency numbers, and data sync.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Protection Settings
  bool _crashDetectionOn = true;
  bool _voiceSOSOn = false;
  String _sensitivityLabel = "Medium";
  int _sosCountdown = 10;

  // Offline Data settings
  int hospitalCount = 124;
  int policeCount = 42;
  String _lastSync = "Yesterday, 14:32";
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Loads configuration values from SharedPreferences.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _crashDetectionOn = prefs.getBool('crash_detection') ?? true;
      _voiceSOSOn = prefs.getBool('voice_sos') ?? false;
      _sensitivityLabel = prefs.getString('sensitivity_label') ?? "Medium";
      _sosCountdown = prefs.getInt('sos_countdown') ?? 10;
      _lastSync = prefs.getString('last_sync') ?? "Yesterday, 14:32";
      hospitalCount = prefs.getInt('hospital_count') ?? 124;
      policeCount = prefs.getInt('police_count') ?? 42;
    });

    // Keep active sensor daemon synced with settings state
    if (_crashDetectionOn) {
      CrashDetector.instance.startListening();
    } else {
      CrashDetector.instance.stopListening();
    }

    final double accel = prefs.getDouble('sensitivity_accel') ?? 25.0;
    final double gyro = prefs.getDouble('sensitivity_gyro') ?? 4.0;
    CrashDetector.instance.updateThresholds(accel: accel, gyro: gyro);
  }

  /// Syncs local database nodes simulating an API request.
  Future<void> _syncData() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
    });

    // Simulate API fetch delay
    await Future.delayed(const Duration(seconds: 2));

    final now = DateTime.now();
    final formattedTime = "Today, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    setState(() {
      _isSyncing = false;
      hospitalCount += 5; // Simulates incremental updates
      policeCount += 2;
      _lastSync = formattedTime;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync', _lastSync);
    await prefs.setInt('hospital_count', hospitalCount);
    await prefs.setInt('police_count', policeCount);
  }

  /// Starts the full simulation flow for crash detection and rescue routing.
  void _startDemo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            "Demo Mode",
            style: AppTypography.headlineMedium.copyWith(color: Colors.white),
          ),
          content: Text(
            "Simulates crash detection without making real emergency calls.",
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "CANCEL",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Pop dialog
                context.go(
                  '/countdown',
                  extra: CrashEvent(
                    timestamp: DateTime.now(),
                    lat: null,
                    lng: null,
                    severity: "HIGH",
                    accelMagnitude: 45.0,
                    gyroMagnitude: 8.0,
                  ),
                );
              },
              child: const Text(
                "START DEMO",
                style: TextStyle(color: AppColors.emergencyRed, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Displays the modal sensitivity picker for sensors.
  void _showSensitivityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DETECTION SENSITIVITY",
                    style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      _buildSensitivityOption(
                        context,
                        "Low",
                        "Fewer false alarms. May miss minor impacts.",
                        35.0,
                        6.0,
                      ),
                      _buildSensitivityOption(
                        context,
                        "Medium",
                        "Balanced. Recommended for most users.",
                        25.0,
                        4.0,
                      ),
                      _buildSensitivityOption(
                        context,
                        "High",
                        "Very sensitive. May have false alarms on bumpy roads.",
                        18.0,
                        2.5,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSensitivityOption(
    BuildContext context,
    String label,
    String desc,
    double accel,
    double gyro,
  ) {
    final isSelected = _sensitivityLabel == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sensitivityLabel = label;
        });
        CrashDetector.instance.updateThresholds(accel: accel, gyro: gyro);
        SharedPreferences.getInstance().then((p) {
          p.setString('sensitivity_label', label);
          p.setDouble('sensitivity_accel', accel);
          p.setDouble('sensitivity_gyro', gyro);
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.headlineMedium.copyWith(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: AppColors.emergencyRed,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a chip-selector for SOS Countdown duration.
  Widget _buildCountdownSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [5, 10, 15].map((seconds) {
        final isSelected = _sosCountdown == seconds;
        return GestureDetector(
          onTap: () {
            setState(() => _sosCountdown = seconds);
            SharedPreferences.getInstance().then((p) => p.setInt('sos_countdown', seconds));
          },
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.emergencyRed : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "${seconds}s",
              style: isSelected
                  ? const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                  : AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Helper list-tile item for uniform settings entries.
  Widget _SettingsTile({
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: subtitle != null ? 64 : 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  /// Builds structured segment headers.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  /// Renders emergency direct call buttons.
  Widget _NumberRow(String emoji, String label, String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final Uri telUri = Uri(scheme: 'tel', path: number);
              if (await canLaunchUrl(telUri)) {
                await launchUrl(telUri);
              }
            },
            child: Text(
              number,
              style: AppTypography.monoMedium.copyWith(color: AppColors.emergencyRed),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Header with Padding
            Padding(
              padding: const EdgeInsets.only(top: 20, left: 20, bottom: 10),
              child: Text(
                "SETTINGS",
                style: AppTypography.headlineLarge.copyWith(color: Colors.white),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PROTECTION SECTION
                    _buildSectionHeader("PROTECTION"),
                    _SettingsTile(
                      title: "Crash Detection",
                      subtitle: "Auto-detects impacts via sensors",
                      trailing: CupertinoSwitch(
                        value: _crashDetectionOn,
                        activeTrackColor: AppColors.safeGreen,
                        onChanged: (v) {
                          setState(() => _crashDetectionOn = v);
                          SharedPreferences.getInstance().then((p) => p.setBool('crash_detection', v));
                          if (v) {
                            CrashDetector.instance.startListening();
                          } else {
                            CrashDetector.instance.stopListening();
                          }
                        },
                      ),
                    ),
                    _SettingsTile(
                      title: "Detection Sensitivity",
                      subtitle: "Current: $_sensitivityLabel",
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onTap: _showSensitivityPicker,
                    ),
                    _SettingsTile(
                      title: "SOS Countdown",
                      trailing: _buildCountdownSelector(),
                    ),
                    _SettingsTile(
                      title: "Voice SOS",
                      subtitle: "Say 'Help RoadSOS' to trigger",
                      trailing: CupertinoSwitch(
                        value: _voiceSOSOn,
                        activeTrackColor: AppColors.safeGreen,
                        onChanged: (v) {
                          setState(() => _voiceSOSOn = v);
                          SharedPreferences.getInstance().then((p) => p.setBool('voice_sos', v));
                        },
                      ),
                    ),

                    // EMERGENCY NUMBERS SECTION
                    _buildSectionHeader("EMERGENCY NUMBERS"),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.borderSubtle, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              "INDIA 🇮🇳",
                              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                            ),
                          ),
                          const Divider(color: AppColors.borderSubtle, height: 1),
                          _NumberRow("🚑", "Ambulance", "108"),
                          _NumberRow("🚔", "Police", "100"),
                          _NumberRow("🔥", "Fire", "101"),
                          _NumberRow("📞", "National", "112"),
                        ],
                      ),
                    ),

                    // OFFLINE DATA SECTION
                    _buildSectionHeader("OFFLINE DATA"),
                    _SettingsTile(
                      title: "Emergency Database",
                      subtitle: "$hospitalCount hospitals · $policeCount police",
                      trailing: GestureDetector(
                        onTap: _syncData,
                        child: _isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.emergencyRed,
                                ),
                              )
                            : Text(
                                "UPDATE ›",
                                style: AppTypography.labelCaps.copyWith(color: AppColors.emergencyRed),
                              ),
                      ),
                    ),
                    _SettingsTile(
                      title: "Last Updated",
                      trailing: Text(
                        _lastSync,
                        style: AppTypography.monoMedium.copyWith(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),

                    // HACKATHON DEMO SECTION
                    _buildSectionHeader("HACKATHON DEMO"),
                    Container(
                      width: double.infinity,
                      color: AppColors.emergencyRed.withOpacity(0.08),
                      child: _SettingsTile(
                        title: "Test SOS — Demo Mode",
                        subtitle: "Full flow simulation. No real calls made.",
                        trailing: Text(
                          "TEST ›",
                          style: AppTypography.labelCaps.copyWith(color: AppColors.emergencyRed),
                        ),
                        onTap: _startDemo,
                      ),
                    ),

                    // ABOUT SECTION
                    _buildSectionHeader("ABOUT"),
                    _SettingsTile(
                      title: "Version",
                      trailing: Text(
                        "RoadSOS v1.0.0",
                        style: AppTypography.monoMedium.copyWith(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    _SettingsTile(
                      title: "Data Sources",
                      trailing: Text(
                        "NHM · OSM · NCRB",
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    _SettingsTile(
                      title: "Share App",
                      onTap: () => Share.share("Check out RoadSOS - Road Emergency & Rescue Operating System app!"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
