import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/utils/music_navigation.dart';
import 'package:plezy/utils/video_player_navigation.dart';
import 'package:plezy/widgets/companion_remote/mobile_remote_shortcut.dart';

void main() {
  test('shortcut remains visible on home and nested content pages', () {
    expect(shouldShowMobileRemoteShortcutOnRoute(routeName: '/', isPopup: false), isTrue);
    expect(shouldShowMobileRemoteShortcutOnRoute(routeName: null, isPopup: false), isTrue);
    expect(shouldShowMobileRemoteShortcutOnRoute(routeName: '/settings', isPopup: false), isTrue);
  });

  test('shortcut stays out of dialogs, remote and fullscreen playback', () {
    expect(shouldShowMobileRemoteShortcutOnRoute(routeName: null, isPopup: true), isFalse);
    expect(
      shouldShowMobileRemoteShortcutOnRoute(
        routeName: kMobileRemoteShortcutRouteName,
        isPopup: false,
      ),
      isFalse,
    );
    expect(
      shouldShowMobileRemoteShortcutOnRoute(routeName: kVideoPlayerRouteName, isPopup: false),
      isFalse,
    );
    expect(
      shouldShowMobileRemoteShortcutOnRoute(routeName: kNowPlayingRouteName, isPopup: false),
      isFalse,
    );
  });
}
