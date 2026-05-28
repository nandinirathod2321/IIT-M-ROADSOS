import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

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

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white, // Always white
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isActive ? AppColors.primaryLight : Colors.transparent,
                            border: Border.all(
                              color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isActive ? tab.activeIcon : tab.icon,
                                size: 24,
                                color: isActive ? AppColors.primary : AppColors.textTertiary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tab.tooltip.toUpperCase(),
                                style: AppTypography.labelCaps.copyWith(
                                  fontSize: 13, // Minimum 13px
                                  color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
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
