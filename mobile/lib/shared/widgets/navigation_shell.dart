import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/tokens.dart';

/// Shell scaffold wrapping the bottom navigation bar around child routes.
class NavigationShell extends StatelessWidget {
  final Widget child;
  final String matchedLocation;

  const NavigationShell({
    super.key,
    required this.child,
    required this.matchedLocation,
  });

  static const _tabs = [
    _NavTab(
      tooltip: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      path: '/',
    ),
    _NavTab(
      tooltip: 'Medical ID',
      icon: Icons.medical_information_outlined,
      activeIcon: Icons.medical_information,
      path: '/medical-id',
    ),
    _NavTab(
      tooltip: 'First Aid',
      icon: Icons.health_and_safety_outlined,
      activeIcon: Icons.health_and_safety,
      path: '/first-aid',
    ),
    _NavTab(
      tooltip: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      path: '/settings',
    ),
  ];

  int _getCurrentIndex() {
    if (matchedLocation == '/') return 0;
    if (matchedLocation.startsWith('/medical-id')) return 1;
    if (matchedLocation.startsWith('/first-aid')) return 2;
    if (matchedLocation.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? DarkColors.borderSubtle : LightColors.borderSubtle;
    final overlay = isDark ? DarkColors.surfaceOverlay : LightColors.surfaceOverlay;
    final muted = isDark ? DarkColors.textMuted : LightColors.textMuted;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.s4, 0, AppTokens.s4, AppTokens.s3),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: AppTokens.r20,
              border: Border.all(color: borderColor),
              color: overlay,
              boxShadow: AppTokens.shadowMd,
            ),
            child: ClipRRect(
              borderRadius: AppTokens.r20,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final isActive = currentIndex == i;
                  final tab = _tabs[i];
                  return Expanded(
                    child: Tooltip(
                      message: tab.tooltip,
                      child: InkWell(
                        onTap: () {
                          if (currentIndex != i) context.go(tab.path);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: AppTokens.r16,
                            color: isActive ? const Color(0x1AE8334A) : Colors.transparent,
                            border: Border.all(
                              color: isActive ? const Color(0x33E8334A) : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isActive ? tab.activeIcon : tab.icon,
                                size: 24,
                                color: isActive ? AppColors.emergencyRed : muted,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tab.tooltip.toUpperCase(),
                                style: AppTypography.labelCaps.copyWith(
                                  fontSize: 9,
                                  color: isActive ? onSurface : muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String tooltip;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _NavTab({
    required this.tooltip,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}
