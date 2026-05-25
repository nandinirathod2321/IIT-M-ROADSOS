import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents application configurations corresponding to the `settings` SQLite table.
class Settings extends Equatable {
  final String id;
  final bool voiceSosEnabled;
  final bool darkMode;
  final bool emergencyAutoShare;
  final bool aiAssistantEnabled;
  final int sosCountdown;
  final bool crashDetectionEnabled;

  const Settings({
    this.id = 'default',
    this.voiceSosEnabled = false,
    this.darkMode = true,
    this.emergencyAutoShare = true,
    this.aiAssistantEnabled = true,
    this.sosCountdown = 5,
    this.crashDetectionEnabled = false,
  });

  // ── Serialisation ────────────────────────────────────────────────────

  factory Settings.fromMap(Map<String, dynamic> map) {
    return Settings(
      id: map['id'] as String? ?? 'default',
      voiceSosEnabled: (map['voice_sos_enabled'] as int? ?? 0) == 1 || map['voice_sos_enabled'] == true,
      darkMode: (map['dark_mode'] as int? ?? 1) == 1 || map['dark_mode'] == true,
      emergencyAutoShare: (map['emergency_auto_share'] as int? ?? 1) == 1 || map['emergency_auto_share'] == true,
      aiAssistantEnabled: (map['ai_assistant_enabled'] as int? ?? 1) == 1 || map['ai_assistant_enabled'] == true,
      sosCountdown: map['sos_countdown'] as int? ?? 5,
      crashDetectionEnabled: (map['crash_detection_enabled'] as int? ?? 0) == 1 || map['crash_detection_enabled'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'voice_sos_enabled': voiceSosEnabled ? 1 : 0,
      'dark_mode': darkMode ? 1 : 0,
      'emergency_auto_share': emergencyAutoShare ? 1 : 0,
      'ai_assistant_enabled': aiAssistantEnabled ? 1 : 0,
      'sos_countdown': sosCountdown,
      'crash_detection_enabled': crashDetectionEnabled ? 1 : 0,
    };
  }

  String toJson() => json.encode(toMap());

  factory Settings.fromJson(String source) => 
      Settings.fromMap(json.decode(source) as Map<String, dynamic>);

  // ── Copy With ────────────────────────────────────────────────────────

  Settings copyWith({
    String? id,
    bool? voiceSosEnabled,
    bool? darkMode,
    bool? emergencyAutoShare,
    bool? aiAssistantEnabled,
    int? sosCountdown,
    bool? crashDetectionEnabled,
  }) {
    return Settings(
      id: id ?? this.id,
      voiceSosEnabled: voiceSosEnabled ?? this.voiceSosEnabled,
      darkMode: darkMode ?? this.darkMode,
      emergencyAutoShare: emergencyAutoShare ?? this.emergencyAutoShare,
      aiAssistantEnabled: aiAssistantEnabled ?? this.aiAssistantEnabled,
      sosCountdown: sosCountdown ?? this.sosCountdown,
      crashDetectionEnabled: crashDetectionEnabled ?? this.crashDetectionEnabled,
    );
  }

  @override
  List<Object?> get props => [
        id,
        voiceSosEnabled,
        darkMode,
        emergencyAutoShare,
        aiAssistantEnabled,
        sosCountdown,
        crashDetectionEnabled,
      ];
}
