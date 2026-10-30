import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/widgets/companion_remote/companion_remote_media_notification.dart';

void main() {
  test('notification is only offered for active Android phone remote playback', () {
    bool show({
      bool phone = true,
      bool connected = true,
      bool playingOnTv = true,
      bool music = false,
    }) => shouldShowRemotePlaybackNotification(
      isAndroidPhone: phone,
      remoteConnected: connected,
      playerActive: playingOnTv,
      localMusicLoaded: music,
    );

    expect(show(), isTrue);
    expect(show(phone: false), isFalse);
    expect(show(connected: false), isFalse);
    expect(show(playingOnTv: false), isFalse);
    expect(show(music: true), isFalse);
  });
}
