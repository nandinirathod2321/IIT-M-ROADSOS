import 'package:flutter/widgets.dart';

import 'theme_provider.dart';

/// Exposes [ThemeProvider] to the widget tree without third-party state libs.
class ThemeScope extends InheritedNotifier<ThemeProvider> {
  const ThemeScope({
    super.key,
    required ThemeProvider notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree.');
    return scope!.notifier!;
  }
}

