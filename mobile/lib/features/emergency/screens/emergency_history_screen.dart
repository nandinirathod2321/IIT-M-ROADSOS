import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/database/database_helper.dart';

/// Screen listing previous SOS activations, timestamps, coordinates, and triggers.
class EmergencyHistoryScreen extends StatefulWidget {
  const EmergencyHistoryScreen({super.key});

  @override
  State<EmergencyHistoryScreen> createState() => _EmergencyHistoryScreenState();
}

class _EmergencyHistoryScreenState extends State<EmergencyHistoryScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _db.getSosEvents();
      setState(() {
        _events = history;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text(
          "CLEAR HISTORY",
          style: AppTypography.headlineMedium.copyWith(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to permanently erase all local incident telemetry and emergency history logs?",
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "CANCEL",
              style: AppTypography.labelCaps.copyWith(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed),
            child: Text(
              "CLEAR",
              style: AppTypography.labelCaps.copyWith(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      // Delete using SharedPreferences on Web, SQLite on Mobile
      await _db.clearSosHistory();
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Emergency history logs cleared successfully.",
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.safeGreen,
          ),
        );
      }
    }
  }

  String _formatTimestamp(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      final date = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      final time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      return "$date @ $time";
    } catch (_) {
      return isoStr;
    }
  }

  Widget _buildTriggerBadge(String trigger) {
    String label = trigger.toUpperCase();
    Color bg = AppColors.surfaceAlt;
    Color text = AppColors.textPrimary;

    if (trigger.toLowerCase() == 'voice') {
      label = "VOICE TRIGGER";
      bg = AppColors.policeBlue.withOpacity(0.15);
      text = AppColors.policeBlue;
    } else if (trigger.toLowerCase() == 'crash') {
      label = "CRASH DETECTED";
      bg = AppColors.emergencyAmber.withOpacity(0.15);
      text = AppColors.emergencyAmber;
    } else if (trigger.toLowerCase() == 'manual') {
      label = "MANUAL SOS";
      bg = AppColors.emergencyRed.withOpacity(0.15);
      text = AppColors.emergencyRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: text.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: AppTypography.monoMedium.copyWith(fontSize: 8.5, color: text, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isResolved = status.toLowerCase() == 'resolved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isResolved ? AppColors.safeGreen.withOpacity(0.12) : AppColors.emergencyRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isResolved ? AppColors.safeGreen.withOpacity(0.3) : AppColors.emergencyRed.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTypography.labelCaps.copyWith(
          fontSize: 8.5,
          color: isResolved ? AppColors.safeGreen : AppColors.emergencyRed,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          "INCIDENT HISTORY",
          style: AppTypography.headlineLarge.copyWith(letterSpacing: 0.5),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => context.pop(),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          if (_events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.emergencyRed),
              onPressed: _clearHistory,
              tooltip: "Clear History",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emergencyRed))
          : _events.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceAlt,
                            border: Border.all(color: AppColors.borderSubtle, width: 1.5),
                          ),
                          child: Icon(Icons.history_toggle_off_rounded, color: AppColors.textMuted.withOpacity(0.5), size: 48),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "NO INCIDENTS LOGGED",
                          style: AppTypography.headlineMedium.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your local emergency timeline and SOS telemetry history will appear here once activated.",
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final String id = event['id'] ?? '--';
                    final String timestamp = event['timestamp'] ?? '';
                    final double lat = event['latitude'] ?? 0.0;
                    final double lng = event['longitude'] ?? 0.0;
                    final String trigger = event['triggerType'] ?? 'manual';
                    final String status = event['status'] ?? 'dispatched';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "EVENT: $id",
                                style: AppTypography.monoMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              _buildStatusBadge(status),
                            ],
                          ),
                          const Divider(color: AppColors.borderSubtle, height: 20),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, color: AppColors.textMuted, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                _formatTimestamp(timestamp),
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E",
                                  style: AppTypography.monoMedium.copyWith(color: AppColors.textPrimary, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTriggerBadge(trigger),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
