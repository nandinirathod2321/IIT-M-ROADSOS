import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_card.dart';

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
      height: 104, // Slightly increased height to accommodate larger font size
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _QuickCard(
            icon: Icons.local_hospital_rounded,
            color: AppColors.primary,
            label: 'Hospitals',
            count: isLoading ? 'Loading...' : '$hospitalCount nearby',
            onTap: () => onTap(0),
          ),
          const SizedBox(width: 10),
          _QuickCard(
            icon: Icons.shield_rounded,
            color: AppColors.primary,
            label: 'Police',
            count: isLoading ? 'Loading...' : '$policeCount nearby',
            onTap: () => onTap(1),
          ),
          const SizedBox(width: 10),
          _QuickCard(
            icon: Icons.local_shipping_rounded,
            color: AppColors.warningAmber,
            label: 'Towing',
            count: isLoading ? 'Loading...' : '$towingCount nearby',
            onTap: () => onTap(2),
          ),
          const SizedBox(width: 10),
          _QuickCard(
            icon: Icons.phone_rounded,
            color: AppColors.emergency,
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
    return SizedBox(
      width: 118,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primaryLight,
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13, // Minimum 13px
                color: AppColors.textSecondary,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
