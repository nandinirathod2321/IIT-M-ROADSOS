import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../bloc/home_state.dart';

/// Card showing crash detection toggle, mesh SOS status, and last DB sync.
class ProtectionStatusCard extends StatelessWidget {
  final bool crashDetectionEnabled;
  final MeshSOSStatus meshStatus;
  final DateTime? lastDbSync;
  final ValueChanged<bool> onCrashDetectionToggled;

  const ProtectionStatusCard({
    super.key,
    required this.crashDetectionEnabled,
    required this.meshStatus,
    this.lastDbSync,
    required this.onCrashDetectionToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Column(
          children: [
            // Crash Detection row
            Row(
              children: [
                Icon(
                  Icons.sensors_rounded,
                  size: 20,
                  color: crashDetectionEnabled
                      ? AppColors.safeGreen
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Crash Detection',
                    style: AppTypography.bodyLarge,
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: crashDetectionEnabled,
                    onChanged: onCrashDetectionToggled,
                    activeThumbColor: AppColors.safeGreen,
                    activeTrackColor: AppColors.safeGreen.withValues(alpha: 0.3),
                    inactiveThumbColor: AppColors.textMuted,
                    inactiveTrackColor: AppColors.surfaceAlt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Mesh SOS row
            Row(
              children: [
                Icon(
                  Icons.hub_rounded,
                  size: 20,
                  color: meshStatus == MeshSOSStatus.active
                      ? AppColors.safeGreen
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Mesh SOS', style: AppTypography.bodyLarge),
                ),
                Text(
                  _meshLabel,
                  style: AppTypography.labelCaps.copyWith(color: _meshColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Last DB Sync row
            Row(
              children: [
                const Icon(
                  Icons.sync_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Last DB Sync', style: AppTypography.bodyLarge),
                ),
                Text(
                  lastDbSync != null
                      ? DateFormat('HH:mm:ss').format(lastDbSync!)
                      : '--:--',
                  style: AppTypography.monoMedium.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _meshLabel {
    switch (meshStatus) {
      case MeshSOSStatus.active:
        return 'ACTIVE';
      case MeshSOSStatus.searching:
        return 'SEARCHING';
      case MeshSOSStatus.disabled:
        return 'DISABLED';
    }
  }

  Color get _meshColor {
    switch (meshStatus) {
      case MeshSOSStatus.active:
        return AppColors.safeGreen;
      case MeshSOSStatus.searching:
        return AppColors.emergencyAmber;
      case MeshSOSStatus.disabled:
        return AppColors.textMuted;
    }
  }
}
