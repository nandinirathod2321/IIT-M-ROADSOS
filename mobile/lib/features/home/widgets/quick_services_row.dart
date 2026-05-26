import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Horizontal row of 4 quick-service cards for the home screen.
class QuickServicesRow extends StatelessWidget {
  final int hospitalCount;
  final int policeCount;
  final int towingCount;
  final int contactsCount;
  final bool isLoading;
  final void Function(int section) onTap;

  const QuickServicesRow({
    super.key,
    required this.hospitalCount,
    required this.policeCount,
    required this.towingCount,
    required this.contactsCount,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _QuickCard(
            icon: Icons.local_hospital_rounded,
            color: AppColors.infoBlue,
            label: 'Hospitals',
            count: isLoading ? 'Loading...' : '$hospitalCount nearby',
            onTap: () => onTap(0),
          ),
          const SizedBox(width: 10),
          _QuickCard(
            icon: Icons.shield_rounded,
            color: AppColors.policeBlue,
            label: 'Police',
            count: isLoading ? 'Loading...' : '$policeCount nearby',
            onTap: () => onTap(1),
          ),
          const SizedBox(width: 10),
          _QuickCard(
            icon: Icons.local_shipping_rounded,
            color: AppColors.towingOrange,
            label: 'Towing',
            count: isLoading ? 'Loading...' : '$towingCount nearby',
            onTap: () => onTap(2),
          ),
          const SizedBox(width: 10),
          _QuickCard(
            icon: Icons.phone_rounded,
            color: AppColors.emergencyRed,
            label: 'Contacts',
            count: '$contactsCount saved',
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String count;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
