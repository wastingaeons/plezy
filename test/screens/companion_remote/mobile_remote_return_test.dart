import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/models/companion_remote/remote_session.dart';
import 'package:plezy/screens/companion_remote/mobile_remote_screen.dart';

void main() {
  test('successful first pairing returns to the browsing route', () {
    expect(
      shouldReturnToBrowsingAfterRemoteConnect(
        initialStatus: RemoteSessionStatus.disconnected,
        isRemote: true,
        isConnected: true,
      ),
      isTrue,
    );
  });

  test('cast from a media item returns to browsing when already paired', () {
    expect(
      shouldReturnToBrowsingAfterRemoteConnect(
        initialStatus: RemoteSessionStatus.connected,
        isRemote: true,
        isConnected: true,
        hasPendingPlay: true,
      ),
      isTrue,
    );
  });

  test('selected media uses the existing TV playMedia wire payload', () {
    const request = CompanionRemotePlayRequest(
      serverId: 'plex-abc',
      ratingKey: '1234',
    );
    expect(request.commandData, {
      'serverId': 'plex-abc',
      'ratingKey': '1234',
    });
  });

  test('pending title cannot play before pairing or on host', () {
    expect(
      shouldReturnToBrowsingAfterRemoteConnect(
        initialStatus: RemoteSessionStatus.disconnected,
        isRemote: true,
        isConnected: false,
        hasPendingPlay: true,
      ),
      isFalse,
    );
    expect(
      shouldReturnToBrowsingAfterRemoteConnect(
        initialStatus: RemoteSessionStatus.disconnected,
        isRemote: false,
        isConnected: true,
        hasPendingPlay: true,
      ),
      isFalse,
    );
  });

  test('opening an already connected remote keeps its controls open', () {
    expect(
      shouldReturnToBrowsingAfterRemoteConnect(
        initialStatus: RemoteSessionStatus.connected,
        isRemote: true,
        isConnected: true,
      ),
      isFalse,
    );
  });

  test('reconnecting remote keeps its controls open', () {
    expect(
      shouldReturnToBrowsingAfterRemoteConnect(
        initialStatus: RemoteSessionStatus.reconnecting,
        isRemote: true,
        isConnected: true,
      ),
      isFalse,
    );
  });

  test('does not navigate away without an established remote connection', () {
    for (final status in [
      RemoteSessionStatus.disconnected,
      RemoteSessionStatus.error,
      RemoteSessionStatus.connecting,
    ]) {
      expect(
        shouldReturnToBrowsingAfterRemoteConnect(
          initialStatus: status,
          isRemote: true,
          isConnected: false,
        ),
        isFalse,
      );
    }
    expect(
      shouldReturnToBrowsingAfterRemoteConnect(
        initialStatus: RemoteSessionStatus.disconnected,
        isRemote: false,
        isConnected: true,
      ),
      isFalse,
    );
  });
}
