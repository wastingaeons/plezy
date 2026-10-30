import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/strings.g.dart';
import '../../navigation/profile_navigation_scope.dart';
import '../../providers/companion_remote_provider.dart';
import '../../screens/companion_remote/mobile_remote_screen.dart';
import '../../utils/music_navigation.dart' show kNowPlayingRouteName;
import '../../utils/platform_detector.dart';
import '../../utils/video_player_navigation.dart' show kVideoPlayerRouteName;

/// Name the route so the persistent shortcut does not cover its own remote UI.
const String kMobileRemoteShortcutRouteName = '/mobile_companion_remote';

/// A route predicate kept separate from widget build for regression tests.
@visibleForTesting
bool shouldShowMobileRemoteShortcutOnRoute({
  required String? routeName,
  required bool isPopup,
}) =>
    !isPopup &&
    routeName != kMobileRemoteShortcutRouteName &&
    routeName != kVideoPlayerRouteName &&
    routeName != kNowPlayingRouteName;

/// Follows the nested profile navigator instead of the root app navigator.
/// The button is mounted *above* that navigator, so page and dialog routes
/// must explicitly control its visibility.
class MobileRemoteShortcutRouteObserver extends NavigatorObserver {
  final ValueNotifier<bool> isVisible = ValueNotifier<bool>(false);
  final List<Route<dynamic>> _routes = [];

  void _update() {
    final top = _routes.isEmpty ? null : _routes.last;
    final show = top != null &&
        shouldShowMobileRemoteShortcutOnRoute(
          routeName: top.settings.name,
          isPopup: top is PopupRoute,
        );
    if (isVisible.value != show) isVisible.value = show;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute != null) {
        _routes[index] = newRoute;
      } else {
        _routes.removeAt(index);
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _update();
  }

  void dispose() {
    isVisible.dispose();
  }
}

/// Android phone shortcut, with an unobtrusive connected-state indicator.
/// Uses the existing MobileRemoteScreen pairing/return-to-browsing behavior.
class MobileCompanionRemoteShortcut extends StatelessWidget {
  const MobileCompanionRemoteShortcut({super.key});

  static bool isSupported(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.android &&
      PlatformDetector.isMobile(context);

  void _openRemote(BuildContext context) {
    // This overlay sits above the profile Navigator; Navigator.of(context)
    // would select the *root* navigator and lose the profile-scoped provider.
    final navigator = ProfileNavigationScope.of(context).navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: kMobileRemoteShortcutRouteName),
        builder: (_) => const MobileRemoteScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<CompanionRemoteProvider>(
      builder: (context, remote, _) => Material(
        color: colorScheme.surfaceContainerHigh,
        elevation: 3,
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: () => _openRemote(context),
          tooltip: t.companionRemote.title,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                remote.isConnected ? Icons.cast_connected_rounded : Icons.cast_rounded,
                color: remote.isConnected ? colorScheme.primary : colorScheme.onSurface,
              ),
              if (remote.isConnected)
                Positioned(
                  top: -3,
                  right: -4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surfaceContainerHigh),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
