import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// Shell scaffold wrapping the bottom navigation bar around child routes.
///
/// Design spec:
///   • Icons only, no labels, tooltips on long-press
///   • Active indicator: emergencyRed horizontal line ABOVE the icon
///   • Outlined icons normally, filled when active
///   • Height: 64px
///   • No ripple — instant color change
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
      bottomNavigationBar: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final isActive = currentIndex == i;
            final tab = _tabs[i];
            return Expanded(
              child: Tooltip(
                message: tab.tooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (currentIndex != i) {
                      context.go(tab.path);
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Active indicator line ABOVE icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 3,
                        width: isActive ? 24 : 0,
                        margin: const EdgeInsets.only(top: 0),
                        decoration: BoxDecoration(
                          color: AppColors.emergencyRed,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isActive ? tab.activeIcon : tab.icon,
                        size: 24,
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          }),
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
