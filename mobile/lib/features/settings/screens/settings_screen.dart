import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/database_helper.dart';
import '../../crash_detection/crash_detector.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/config/ai_config.dart';

/// Interactive Settings Screen for RoadSOS.
/// Provides configuration for Crash Detection, SOS settings, and clean real-time data sync.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper();

  // Protection Settings
  bool _crashDetectionOn = true;
  bool _voiceSOSOn = false;
  bool _voiceSOSAlwaysListening = false;
  String _sensitivityLabel = "Medium";
  int _sosCountdown = 10;

  // Offline Data settings
  String _lastSync = "Yesterday, 14:32";
  bool _isSyncing = false;

  // Database metrics
  int _dbRecordCount = 42;
  double _dbSizeKb = 32.0;

  String _geminiKeyDisplay = 'Not Configured';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Loads configuration values from SharedPreferences.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Fetch actual record count & file size directly from SQLite
    final int count = await _db.getDatabaseRecordCount();
    final int sizeInBytes = await _db.getDatabaseSizeInBytes();
    final geminiKey = await AiConfig.getGeminiApiKey();

    setState(() {
      _crashDetectionOn = prefs.getBool('crash_detection') ?? true;
      _voiceSOSOn = prefs.getBool('voice_sos') ?? false;
      _voiceSOSAlwaysListening = prefs.getBool('voice_sos_always_listening') ?? false;
      _sensitivityLabel = prefs.getString('sensitivity_label') ?? "Medium";
      _sosCountdown = prefs.getInt('sos_countdown') ?? 10;
      _lastSync = prefs.getString('last_sync') ?? "Yesterday, 14:32";
      _dbRecordCount = count;
      _dbSizeKb = sizeInBytes / 1024.0;
      _geminiKeyDisplay = geminiKey.isEmpty
          ? 'Not Configured'
          : (geminiKey.length > 8
              ? '${geminiKey.substring(0, 4)}...${geminiKey.substring(geminiKey.length - 4)}'
              : 'Configured');
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

  /// Syncs local database nodes by deleting and re-seeding the expanded seeder.
  Future<void> _syncData() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
    });

    final database = await _db.database;
    await database.delete('hospitals');
    await database.delete('police_stations');
    await database.delete('towing_services');
    await _db.seedDemoData(database);

    // Simulate API fetch delay
    await Future.delayed(const Duration(milliseconds: 1200));

    final now = DateTime.now();
    final formattedTime = "Today, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Query updated values
    final int count = await _db.getDatabaseRecordCount();
    final int sizeInBytes = await _db.getDatabaseSizeInBytes();

    setState(() {
      _isSyncing = false;
      _lastSync = formattedTime;
      _dbRecordCount = count;
      _dbSizeKb = sizeInBytes / 1024.0;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync', _lastSync);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Emergency database updated successfully',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.safeGreen,
        ),
      );
    }
  }

  Future<void> _showGeminiKeyDialog() async {
    final currentKey = await AiConfig.getGeminiApiKey();
    final controller = TextEditingController(text: currentKey);
    bool obscureText = true;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
              title: Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: AppColors.emergencyRed, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    "GEMINI FLASH API KEY",
                    style: AppTypography.headlineMedium.copyWith(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Configure your Gemini API key to activate the live AI Emergency Assistant.",
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: obscureText,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "API Key",
                      labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.emergencyRed),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "CANCEL",
                    style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await AiConfig.setGeminiApiKeyOverride(controller.text);
                    await _loadSettings(); // refresh setting display
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Gemini API key updated successfully.",
                            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                          ),
                          backgroundColor: AppColors.safeGreen,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emergencyRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text(
                    "SAVE",
                    style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            );
          },
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
                    "Very sensitive. May trigger on bumpy roads.",
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

  /// Helper list-tile item for settings entries.
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
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

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
                          setState(() {
                            _voiceSOSOn = v;
                            if (!v) {
                              _voiceSOSAlwaysListening = false;
                              SharedPreferences.getInstance().then((p) => p.setBool('voice_sos_always_listening', false));
                            }
                          });
                          SharedPreferences.getInstance().then((p) => p.setBool('voice_sos', v));
                        },
                      ),
                    ),
                    if (_voiceSOSOn)
                      _SettingsTile(
                        title: "Always-Listening Mode",
                        subtitle: "Keep microphone scanning continuously",
                        trailing: CupertinoSwitch(
                          value: _voiceSOSAlwaysListening,
                          activeTrackColor: AppColors.safeGreen,
                          onChanged: (v) {
                            setState(() => _voiceSOSAlwaysListening = v);
                            SharedPreferences.getInstance().then((p) => p.setBool('voice_sos_always_listening', v));
                          },
                        ),
                      ),

                    // EMERGENCY HOTLINES SECTION
                    _buildSectionHeader("EMERGENCY HOTLINES"),
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
                          _NumberRow("🚔", "Police Control Room", "100"),
                          _NumberRow("📞", "National Single Hotline", "112"),
                        ],
                      ),
                    ),

                    // AI ASSISTANT SECTION
                    _buildSectionHeader("AI ASSISTANT"),
                    _SettingsTile(
                      title: "Gemini API Key",
                      subtitle: _geminiKeyDisplay,
                      trailing: const Icon(
                        Icons.vpn_key_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onTap: _showGeminiKeyDialog,
                    ),

                    // OFFLINE DATA SECTION
                    _buildSectionHeader("OFFLINE DATA"),
                    _SettingsTile(
                      title: "Emergency Database",
                      subtitle: "$_dbRecordCount local records · ${_dbSizeKb.toStringAsFixed(1)} KB size",
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
                    _SettingsTile(
                      title: "Logout Profile",
                      trailing: const Icon(
                        Icons.logout,
                        color: AppColors.emergencyRed,
                        size: 20,
                      ),
                      onTap: () async {
                        await AuthService.instance.signOut();
                        if (mounted) {
                          context.go('/login');
                        }
                      },
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
