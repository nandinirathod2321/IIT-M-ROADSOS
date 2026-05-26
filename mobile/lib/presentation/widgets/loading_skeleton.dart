import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/colors.dart';

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.borderSubtle, width: 4),
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceAlt,
        highlightColor: AppColors.surface.withOpacity(0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upper Tag Area
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 70,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Title Area
                  Container(
                    width: double.infinity,
                    height: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  // Address Area
                  Container(
                    width: 180,
                    height: 12,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Button skeleton
            Container(
              width: 60,
              height: 36,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingListSkeleton extends StatelessWidget {
  final int count;

  const LoadingListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => const LoadingSkeleton(),
    );
  }
}
