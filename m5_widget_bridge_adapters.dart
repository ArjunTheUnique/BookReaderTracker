// ============================================================
// PLATFORM EDGE — M5 Widget Bridge adapters
// Version Stamp : v1.0
// Pairs with    : src/modules/m5_widget_bridge.dart
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   M5's logic must not import the widget plugin directly. This is the
//   edge: the only place `home_widget` appears. The module declares the
//   WidgetHost port; this file implements it for a real device.
//
//   It is NOT imported by the module or by the test suite, so the tests
//   stay free of platform plugins. The app shell wires it in at startup.
//
// DO NOT put business rules here — only transport.
// ============================================================

import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import 'm5_widget_bridge.dart';

/// The real widget edge: writes the payload into the shared app-group
/// store through home_widget, then asks the OS to refresh the widget.
class HomeWidgetHost implements WidgetHost {
  @override
  Future<void> writePayload(Map<String, dynamic> payload) async {
    try {
      await HomeWidget.saveWidgetData<String>(
          'shelf_payload', jsonEncode(payload));
      await HomeWidget.updateWidget(name: 'ShelfWidget');
    } catch (e) {
      final String s = e.toString().toLowerCase();
      // home_widget surfaces permission refusals as a platform error;
      // route those to E8 and everything else to E7.
      if (s.contains('permission') || s.contains('denied')) {
        throw WidgetHostPermissionDenied(s);
      }
      throw WidgetHostStorageError(s);
    }
  }

  @override
  Future<String> healthCheck() async {
    // home_widget has no probe; the module treats this as "host alive".
    return 'ok';
  }
}
