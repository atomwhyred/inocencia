import 'package:flutter/widgets.dart';

/// Clases de tamano de ventana (Material 3) para adaptar telefono y tablet.
enum WindowSizeClass {
  compact, // < 600 dp
  medium, // 600-840 dp
  expanded; // > 840 dp

  static WindowSizeClass fromWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  static WindowSizeClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == WindowSizeClass.compact;
  bool get isExpanded => this == WindowSizeClass.expanded;
}
