import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';

class BottomNavShell extends StatelessWidget {
  final Widget child;

  const BottomNavShell({super.key, required this.child});

  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Feed',
      icon: Icons.view_stream_outlined,
      activeIcon: Icons.view_stream_rounded,
      path: '/feed',
    ),
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      path: '/home',
    ),
    _NavItem(
      label: 'Requests',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      path: '/portal',
    ),
    _NavItem(
      label: 'Prices',
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments_rounded,
      path: '/marketplace',
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      path: '/profile',
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/feed')) return 0;
    if (location.startsWith('/home')) return 1;
    if (location.startsWith('/portal')) return 2;
    if (location.startsWith('/marketplace')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    final item = _navItems[index];
    final current = GoRouterState.of(context).matchedLocation;
    if (current == item.path) return;
    context.go(item.path);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          height: 72,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => _onTap(context, index),
          destinations: [
            for (final item in _navItems)
              NavigationDestination(
                icon: Icon(item.icon, size: 23, color: AppColors.textSecondary),
                selectedIcon: Icon(
                  item.activeIcon,
                  size: 23,
                  color: AppColors.primary,
                ),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });
}
