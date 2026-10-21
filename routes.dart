// ============================================================
// INTEGRATION FILE — INT-1 src/app/routes.dart
// Version Stamp : v1.0
// Part of       : INT-1 App Shell & Wiring
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   A widget tap (M5) produces a deep-link string like
//   "shelf://book/<id>". This file turns that string into a
//   screen target the shell can open — including on a cold start.
//
// DO NOT TOUCH the route format: M5 mints it and the native widget
// passes it back, so both sides must agree.
// ============================================================

/// Where a deep link should land.
class RouteTarget {
  RouteTarget.book(this.id) : view = 'book';
  RouteTarget.category(this.id) : view = 'category';

  /// 'book' or 'category' — matches M7's `view` values.
  final String view;

  /// The id M7 will be asked for.
  final String id;

  @override
  String toString() => 'RouteTarget($view, $id)';
}

/// Maps the widget's tap route to the right screen.
class AppRoutes {
  const AppRoutes();

  /// Parse `shelf://book/<id>` or `shelf://category/<id>`.
  /// Returns null for anything else, so the shell can fall back home.
  RouteTarget? resolve(String route) {
    final Uri? uri = Uri.tryParse(route);
    if (uri == null || uri.scheme != 'shelf') return null;
    final String id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (id.isEmpty) return null;
    switch (uri.host) {
      case 'book':
        return RouteTarget.book(id);
      case 'category':
        return RouteTarget.category(id);
      default:
        return null;
    }
  }
}
