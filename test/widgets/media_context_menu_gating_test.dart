import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/models/companion_remote/remote_session.dart';
import 'package:plezy/widgets/media_context_menu.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/media_version.dart';
import 'package:plezy/widgets/media_context_menu.dart';

void main() {
  group('Cast to device context menu entry', () {
    bool offer({
      bool isAndroidPhone = true,
      bool isRemotePlayableMedia = true,
      RemoteSessionStatus? status = RemoteSessionStatus.disconnected,
      bool isHosting = false,
    }) => canOfferCastToDeviceOnMediaMenu(
      isAndroidPhone: isAndroidPhone,
      isRemotePlayableMedia: isRemotePlayableMedia,
      remoteStatus: status,
      isHosting: isHosting,
    );

    test('offers chooser for playable media on a disconnected Android phone', () {
      expect(offer(), isTrue);
      expect(offer(status: RemoteSessionStatus.error), isTrue);
    });

    test('does not duplicate the connected-device or in-progress actions', () {
      expect(offer(status: RemoteSessionStatus.connected), isFalse);
      expect(offer(status: RemoteSessionStatus.connecting), isFalse);
      expect(offer(status: RemoteSessionStatus.reconnecting), isFalse);
    });

    test('never offers chooser on unsupported platforms, host or other media', () {
      expect(offer(isAndroidPhone: false), isFalse);
      expect(offer(isRemotePlayableMedia: false), isFalse);
      expect(offer(isHosting: true), isFalse);
      expect(offer(status: null), isFalse);
    });
  });

  group('hasKnownNoPlayableMedia', () {
    test(
      'Plex movie with an explicitly empty version list is metadata-only',
      () {
        expect(
          hasKnownNoPlayableMedia(
            kind: MediaKind.movie,
            backend: MediaBackend.plex,
            mediaVersions: const <MediaVersion>[],
            leafCount: null,
          ),
          isTrue,
        );
      },
    );

    test('Jellyfin movie with a null version list fails open (listings omit MediaSources)', () {
      expect(
        hasKnownNoPlayableMedia(
          kind: MediaKind.movie,
          backend: MediaBackend.jellyfin,
          mediaVersions: null,
          leafCount: null,
        ),
        isFalse,
      );
    });

    test(
      'show with an explicit leafCount of 0 is metadata-only on any backend',
      () {
        expect(
          hasKnownNoPlayableMedia(
            kind: MediaKind.show,
            backend: MediaBackend.jellyfin,
            mediaVersions: null,
            leafCount: 0,
          ),
          isTrue,
        );
      },
    );

    test('show with a null leafCount fails open', () {
      expect(
        hasKnownNoPlayableMedia(
          kind: MediaKind.show,
          backend: MediaBackend.plex,
          mediaVersions: null,
          leafCount: null,
        ),
        isFalse,
      );
    });
  });
}
