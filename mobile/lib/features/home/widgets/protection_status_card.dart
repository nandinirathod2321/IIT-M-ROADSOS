import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../bloc/home_state.dart';

/// Interactive card showing crash detection toggle, animated Mesh SOS peer sync, and database status.
class ProtectionStatusCard extends StatefulWidget {
  final bool crashDetectionEnabled;
  final MeshSOSStatus meshStatus;
  final int nearbyDevicesCount;
  final String signalQuality;
  final String syncStatus;
  final DateTime? lastDbSync;
  final ValueChanged<bool> onCrashDetectionToggled;

  const ProtectionStatusCard({
    super.key,
    required this.crashDetectionEnabled,
    required this.meshStatus,
    required this.nearbyDevicesCount,
    required this.signalQuality,
    required this.syncStatus,
    this.lastDbSync,
    required this.onCrashDetectionToggled,
  });

  @override
  State<ProtectionStatusCard> createState() => _ProtectionStatusCardState();
}

class _ProtectionStatusCardState extends State<ProtectionStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseScale = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

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
                  color: widget.crashDetectionEnabled
                      ? AppColors.safeGreen
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crash Detection',
                        style: AppTypography.bodyLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.crashDetectionEnabled
                            ? 'Sensors armed & listening in background'
                            : 'Sensors disarmed — Emergency triggers OFF',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: widget.crashDetectionEnabled
                              ? AppColors.safeGreen
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: widget.crashDetectionEnabled,
                    onChanged: widget.onCrashDetectionToggled,
                    activeThumbColor: AppColors.safeGreen,
                    activeTrackColor: AppColors.safeGreen.withOpacity(0.3),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      size: 20,
                      color: _getMeshIconColor(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Mesh SOS', style: AppTypography.bodyLarge),
                    ),
                    // Animated Status Dot
                    if (widget.meshStatus != MeshSOSStatus.disabled)
                      AnimatedBuilder(
                        animation: _pulseScale,
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _pulseScale.value,
                            child: Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getMeshDotColor(),
                              ),
                            ),
                          );
                        },
                      ),
                    Text(
                      _meshLabel,
                      style: AppTypography.labelCaps.copyWith(
                        color: _meshColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (widget.meshStatus != MeshSOSStatus.disabled) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      _meshSubtitle,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
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
                  widget.lastDbSync != null
                      ? DateFormat('HH:mm:ss').format(widget.lastDbSync!)
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

  Color _getMeshIconColor() {
    switch (widget.meshStatus) {
      case MeshSOSStatus.active:
        return AppColors.safeGreen;
      case MeshSOSStatus.connecting:
        return AppColors.emergencyAmber;
      case MeshSOSStatus.offline:
        return AppColors.emergencyRed;
      case MeshSOSStatus.disabled:
        return AppColors.textMuted;
    }
  }

  Color _getMeshDotColor() {
    switch (widget.meshStatus) {
      case MeshSOSStatus.active:
        return AppColors.statusActive;
      case MeshSOSStatus.connecting:
        return AppColors.emergencyAmber;
      case MeshSOSStatus.offline:
        return AppColors.emergencyRed;
      case MeshSOSStatus.disabled:
        return AppColors.textMuted;
    }
  }

  String get _meshLabel {
    switch (widget.meshStatus) {
      case MeshSOSStatus.active:
        return 'ACTIVE';
      case MeshSOSStatus.connecting:
        return 'CONNECTING...';
      case MeshSOSStatus.offline:
        return 'OFFLINE';
      case MeshSOSStatus.disabled:
        return 'DISABLED';
    }
  }

  String get _meshSubtitle {
    switch (widget.meshStatus) {
      case MeshSOSStatus.active:
        return 'Cellular online · ${widget.syncStatus}\n(${widget.nearbyDevicesCount} BLE peers synced · Signal: ${widget.signalQuality})';
      case MeshSOSStatus.connecting:
        return '${widget.syncStatus} (Signal: ${widget.signalQuality})';
      case MeshSOSStatus.offline:
        return 'Cellular down · ${widget.syncStatus}\n(${widget.nearbyDevicesCount} local peers linked · Signal: ${widget.signalQuality})';
      case MeshSOSStatus.disabled:
        return 'Mesh networking disarmed';
    }
  }

  Color get _meshColor {
    switch (widget.meshStatus) {
      case MeshSOSStatus.active:
        return AppColors.safeGreen;
      case MeshSOSStatus.connecting:
        return AppColors.emergencyAmber;
      case MeshSOSStatus.offline:
        return AppColors.emergencyRed;
      case MeshSOSStatus.disabled:
        return AppColors.textMuted;
    }
  }
}
