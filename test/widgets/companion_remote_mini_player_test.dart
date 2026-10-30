import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/widgets/companion_remote/companion_remote_mini_player.dart';

void main() {
  test('remote mini-player only shows on browsing Android phones with playback', () {
    bool visible({
      bool phone = true,
      bool route = true,
      bool connected = true,
      bool active = true,
      bool music = false,
    }) => shouldShowCompanionRemoteMiniPlayer(
      androidPhone: phone,
      routeVisible: route,
      remoteConnected: connected,
      playerActive: active,
      localMusicLoaded: music,
    );
    expect(visible(), isTrue);
    expect(visible(phone: false), isFalse);
    expect(visible(route: false), isFalse);
    expect(visible(connected: false), isFalse);
    expect(visible(active: false), isFalse);
    expect(visible(music: true), isFalse);
  });

  test('display-only progress clamps valid and invalid inputs', () {
    expect(companionMiniPlayerProgress(const Duration(seconds: 25), const Duration(seconds: 100)), .25);
    expect(companionMiniPlayerProgress(Duration.zero, Duration.zero), 0);
    expect(companionMiniPlayerProgress(const Duration(seconds: 120), const Duration(seconds: 100)), 1);
    expect(companionMiniPlayerProgress(const Duration(seconds: -1), const Duration(seconds: 100)), 0);
  });
}
