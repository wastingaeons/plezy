import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/media_backend.dart';

import 'package:plezy/media/media_kind.dart';
import 'package:plezy/services/settings_service.dart';
import 'package:plezy/utils/media_navigation_helper.dart';

import '../test_helpers/media_items.dart';

void main() {
  test(
    'episode detail target opens parent show and focuses season episode',
    () {
      final episode = testMediaItem(
        id: 'episode-1',
        backend: MediaBackend.plex,
        kind: MediaKind.episode,
        title: 'Episode 1',
        parentId: 'season-2',
        parentIndex: 2,
        grandparentId: 'show-1',
        grandparentTitle: 'The Show',
        serverId: 'server-1',
      );

      final target = mediaDetailNavigationTargetFor(episode);

      expect(target.metadata.id, 'show-1');
      expect(target.metadata.kind, MediaKind.show);
      expect(target.initialSeasonId, 'season-2');
      expect(target.initialSeasonIndex, 2);
      expect(target.initialEpisodeId, 'episode-1');
    },
  );

  test('season detail target opens parent show and focuses season', () {
    final season = testMediaItem(
      id: 'season-3',
      backend: MediaBackend.jellyfin,
      kind: MediaKind.season,
      title: 'Season 3',
      index: 3,
      parentId: 'show-1',
      parentTitle: 'The Show',
      serverId: 'server-1',
    );

    final target = mediaDetailNavigationTargetFor(season);

    expect(target.metadata.id, 'show-1');
    expect(target.metadata.kind, MediaKind.show);
    expect(target.initialSeasonId, 'season-3');
    expect(target.initialSeasonIndex, 3);
    expect(target.initialEpisodeId, isNull);
  });

  test('movie detail target keeps the movie itself', () {
    final movie = testMediaItem(
      id: 'movie-1',
      backend: MediaBackend.plex,
      kind: MediaKind.movie,
      title: 'Movie',
    );

    final target = mediaDetailNavigationTargetFor(movie);

    expect(target.metadata, same(movie));
    expect(target.initialSeasonId, isNull);
    expect(target.initialEpisodeId, isNull);
  });

  group('paired-device tap interception', () {
    test('offers casting only on individual movies and episodes', () {
      for (final kind in [MediaKind.movie, MediaKind.episode]) {
        expect(
          shouldOfferConnectedPlayback(
            isOffline: false,
            isRemote: true,
            isConnected: true,
            serverId: 'server-1',
            kind: kind,
          ),
          isTrue,
          reason: '$kind is a single playable media item',
        );
      }
    });

    test('shows, seasons, clips and music do not trigger cast prompt', () {
      for (final kind in [
        MediaKind.show,
        MediaKind.season,
        MediaKind.track,
        MediaKind.album,
        MediaKind.clip,
      ]) {
        expect(
          shouldOfferConnectedPlayback(
            isOffline: false,
            isRemote: true,
            isConnected: true,
            serverId: 'server-1',
            kind: kind,
          ),
          isFalse,
        );
      }
    });

    test('never interrupts unpaired, offline or serverless activation', () {
      for (final state in [
        (
          isOffline: false,
          isRemote: false,
          isConnected: true,
          serverId: 'server-1',
        ),
        (
          isOffline: false,
          isRemote: true,
          isConnected: false,
          serverId: 'server-1',
        ),
        (
          isOffline: true,
          isRemote: true,
          isConnected: true,
          serverId: 'server-1',
        ),
        (isOffline: false, isRemote: true, isConnected: true, serverId: null),
      ]) {
        expect(
          shouldOfferConnectedPlayback(
            isOffline: state.isOffline,
            isRemote: state.isRemote,
            isConnected: state.isConnected,
            serverId: state.serverId,
          ),
          isFalse,
        );
      }
    });
  });

  group('episode activation details decision', () {
    test('normal activation uses the episode action setting', () {
      expect(
        shouldOpenEpisodeDetailsForActivation(
          playDirectly: false,
          continueWatchingAction: ContinueWatchingAction.details,
          episodeAction: EpisodeAction.play,
        ),
        isFalse,
      );

      expect(
        shouldOpenEpisodeDetailsForActivation(
          playDirectly: false,
          continueWatchingAction: ContinueWatchingAction.play,
          episodeAction: EpisodeAction.details,
        ),
        isTrue,
      );
    });

    test(
      'play-direct activation uses only the continue watching action setting',
      () {
        expect(
          shouldOpenEpisodeDetailsForActivation(
            playDirectly: true,
            continueWatchingAction: ContinueWatchingAction.play,
            episodeAction: EpisodeAction.details,
          ),
          isFalse,
        );

        expect(
          shouldOpenEpisodeDetailsForActivation(
            playDirectly: true,
            continueWatchingAction: ContinueWatchingAction.details,
            episodeAction: EpisodeAction.play,
          ),
          isTrue,
        );
      },
    );
  });
}
