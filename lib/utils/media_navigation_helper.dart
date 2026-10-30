import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../media/catalog_item_ref.dart';
import '../media/ids.dart';
import '../media/media_backend.dart';
import '../media/media_item.dart';
import '../media/media_item_types.dart';
import '../media/media_kind.dart';
import '../media/media_playlist.dart';
import '../models/companion_remote/remote_command.dart';
import '../providers/companion_remote_provider.dart';
import '../screens/actor_media_screen.dart';
import '../screens/collection_detail_screen.dart';
import '../screens/main_screen.dart';
import '../screens/media_detail_screen.dart';
import '../screens/playlist/playlist_detail_screen.dart';
import '../services/settings_service.dart';
import '../utils/global_key_utils.dart';
import 'catalog_navigation_helper.dart';
import 'music_navigation.dart';
import 'plex_library_section_utils.dart';
import 'video_player_navigation.dart';

/// Result of media navigation indicating what action was taken
enum MediaNavigationResult {
  /// Navigation completed successfully
  navigated,

  /// Navigation completed, parent list should be refreshed (e.g., collection deleted)
  listRefreshNeeded,

  /// Item type not supported (e.g., photos)
  unsupported,

  /// Item is a library section — navigated to that library
  librarySelected,
}

class MediaDetailNavigationTarget {
  final MediaItem metadata;
  final int? initialSeasonIndex;
  final String? initialSeasonId;
  final String? initialEpisodeId;

  const MediaDetailNavigationTarget({
    required this.metadata,
    this.initialSeasonIndex,
    this.initialSeasonId,
    this.initialEpisodeId,
  });
}

MediaDetailNavigationTarget mediaDetailNavigationTargetFor(
  MediaItem item, {
  MediaItem? metadataOverride,
}) {
  if (item.isEpisode && item.grandparentId != null) {
    return MediaDetailNavigationTarget(
      metadata:
          metadataOverride ??
          MediaItem(
            id: item.grandparentId!,
            backend: item.backend,
            kind: MediaKind.show,
            title: item.grandparentTitle ?? item.displayTitle,
            thumbPath: item.grandparentThumbPath,
            artPath: item.grandparentArtPath,
            libraryId: item.libraryId,
            libraryTitle: item.libraryTitle,
            serverId: item.serverId,
            serverName: item.serverName,
          ),
      initialSeasonIndex: item.parentIndex,
      initialSeasonId: item.parentId,
      initialEpisodeId: item.id,
    );
  }

  if (item.isEpisode && item.parentId != null) {
    return MediaDetailNavigationTarget(
      metadata:
          metadataOverride ??
          MediaItem(
            id: item.parentId!,
            backend: item.backend,
            kind: MediaKind.season,
            title:
                item.parentTitle ??
                t.common.seasonNumber(number: item.parentIndex ?? ''),
            index: item.parentIndex,
            thumbPath: item.parentThumbPath,
            parentId: item.grandparentId,
            libraryId: item.libraryId,
            libraryTitle: item.libraryTitle,
            serverId: item.serverId,
            serverName: item.serverName,
          ),
      initialEpisodeId: item.id,
    );
  }

  if (item.isSeason && item.parentId != null) {
    return MediaDetailNavigationTarget(
      metadata:
          metadataOverride ??
          MediaItem(
            id: item.parentId!,
            backend: item.backend,
            kind: MediaKind.show,
            title:
                item.grandparentTitle ?? item.parentTitle ?? item.displayTitle,
            thumbPath: item.grandparentThumbPath ?? item.parentThumbPath,
            artPath: item.grandparentArtPath,
            libraryId: item.libraryId,
            libraryTitle: item.libraryTitle,
            serverId: item.serverId,
            serverName: item.serverName,
          ),
      initialSeasonIndex: item.index,
      initialSeasonId: item.id,
    );
  }

  return MediaDetailNavigationTarget(metadata: metadataOverride ?? item);
}

bool shouldOpenEpisodeDetailsForActivation({
  required bool playDirectly,
  required ContinueWatchingAction continueWatchingAction,
  required EpisodeAction episodeAction,
}) {
  if (playDirectly)
    return continueWatchingAction == ContinueWatchingAction.details;
  return episodeAction == EpisodeAction.details;
}

/// Only a single playable video (movie or episode) should ask where to play.
/// Series and season cards must navigate normally, even while paired.
bool shouldOfferConnectedPlayback({
  required bool isOffline,
  required bool isRemote,
  required bool isConnected,
  required String? serverId,
  MediaKind kind = MediaKind.movie,
}) =>
    !isOffline &&
    isRemote &&
    isConnected &&
    serverId != null &&
    (kind == MediaKind.movie || kind == MediaKind.episode);

/// A cancelled dialog must never accidentally launch a local player.
enum CompanionPlaybackTarget { local, connected, details, cancelled }

Future<CompanionPlaybackTarget> chooseConnectedPlaybackTarget(
  BuildContext context,
  MediaItem item, {
  required bool isOffline,
}) async {
  final remote = context.read<CompanionRemoteProvider?>();
  if (!shouldOfferConnectedPlayback(
    isOffline: isOffline,
    isRemote: remote?.isRemote ?? false,
    isConnected: remote?.isConnected ?? false,
    serverId: item.serverId,
    kind: item.kind,
  )) {
    return CompanionPlaybackTarget.local;
  }

  final choice = await showDialog<CompanionPlaybackTarget>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('What would you like to do?'),
      content: Text(item.displayTitle),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(CompanionPlaybackTarget.details),
          child: const Text('View Details'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(CompanionPlaybackTarget.local),
          child: const Text('Play Here'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.cast_rounded),
          label: const Text('Play on Connected Device'),
          onPressed: () =>
              Navigator.of(dialogContext)
                  .pop(CompanionPlaybackTarget.connected),
        ),
      ],
    ),
  );

  if (!context.mounted || choice == null)
    return CompanionPlaybackTarget.cancelled;
  if (choice == CompanionPlaybackTarget.connected) {
    // The pairing may have disappeared while the chooser was open.
    if (remote == null || !remote.isRemote || !remote.isConnected) {
      return CompanionPlaybackTarget.cancelled;
    }
    remote.sendCommand(
      RemoteCommandType.playMedia,
      data: {'serverId': item.serverId, 'ratingKey': item.id},
    );
  }
  return choice;
}

/// Navigates to the appropriate screen based on the item type.
///
/// Accepts a [MediaItem] or a [MediaPlaylist] (typed as [Object] because Dart
/// has no nominal union type).
///
/// For episodes, normal card activation follows the Episode Action setting;
/// [playDirectly] surfaces instead follow the Continue Watching action setting.
/// For movies, starts playback directly if [playDirectly] is true and the
/// Continue Watching details setting is disabled; otherwise navigates to media
/// detail screen.
/// For seasons, navigates to season detail screen.
/// For playlists, navigates to playlist detail screen.
/// For collections, navigates to collection detail screen.
/// For other types (shows), navigates to media detail screen.
/// For artists/albums, navigates to the music detail screens; tracks start
/// playback in their album queue.
///
/// The [onRefresh] callback is invoked with the source item after returning
/// from the detail screen, preserving its server-qualified identity.
///
/// Set [isOffline] to true for downloaded content without server access.
///
/// Set [playDirectly] to true for Continue Watching / Next Up / On Deck
/// activation; those surfaces use the Continue Watching action setting instead
/// of the normal Episode Action setting.
///
/// Returns a [MediaNavigationResult] indicating what action was taken:
/// - [MediaNavigationResult.navigated]: Navigation completed, item refresh handled
/// - [MediaNavigationResult.listRefreshNeeded]: Caller should refresh entire list
/// - [MediaNavigationResult.unsupported]: Item type not supported, caller should handle
Future<MediaNavigationResult> navigateToMediaItem(
  BuildContext context,
  Object item, {
  void Function(MediaItem source)? onRefresh,
  bool isOffline = false,
  bool playDirectly = false,
}) async {
  if (item is MediaPlaylist) {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailScreen(playlist: item),
      ),
    );
    return result == true
        ? MediaNavigationResult.listRefreshNeeded
        : MediaNavigationResult.navigated;
  }

  if (item is! MediaItem) {
    return MediaNavigationResult.unsupported;
  }
  final mi = item;

  // Catalog stand-ins (Explore tab) have no server id — every server-backed
  // route below would break on them. Route to the catalog flow instead.
  if (mi.isCatalogItem) {
    final catalogItem = mi.catalogItem;
    if (catalogItem == null) return MediaNavigationResult.unsupported;
    await navigateToCatalogItem(context, catalogItem);
    return MediaNavigationResult.navigated;
  }
  final settings = SettingsService.instanceOrNull;
  final continueWatchingAction =
      settings?.read(SettingsService.continueWatchingAction) ??
      ContinueWatchingAction.play;
  final episodeAction =
      settings?.read(SettingsService.episodeAction) ?? EpisodeAction.play;
  final shouldOpenContinueWatchingDetails =
      playDirectly && continueWatchingAction == ContinueWatchingAction.details;
  final shouldOpenEpisodeDetails = shouldOpenEpisodeDetailsForActivation(
    playDirectly: playDirectly,
    continueWatchingAction: continueWatchingAction,
    episodeAction: episodeAction,
  );

  // Handle library section items (shared whole-library entries) — Plex-only;
  // `PlexMappers` stashes the section path in `raw['key']`. Jellyfin "views"
  // never appear inside a [MediaItem], so the gate never fires for them.
  final rawKey = mi.raw?['key'];
  if (rawKey is String && rawKey.startsWith('/library/sections/')) {
    final sectionId = plexLibrarySectionIdFromString(rawKey);
    if (sectionId != null && mi.serverId != null) {
      final libraryGlobalKey = buildGlobalKey(
        ServerId(mi.serverId!),
        '$sectionId',
      );
      MainScreenFocusScope.of(
        context,
        listen: false,
      )?.selectLibrary?.call(libraryGlobalKey);
      return MediaNavigationResult.librarySelected;
    }
    return MediaNavigationResult.unsupported;
  }

  // All normal media card taps share this single chooser, including library
  // movie and series cards that ordinarily open details directly.
  final target = await chooseConnectedPlaybackTarget(
    context,
    mi,
    isOffline: isOffline,
  );
  if (target == CompanionPlaybackTarget.cancelled || !context.mounted) {
    return MediaNavigationResult.navigated;
  }
  if (target == CompanionPlaybackTarget.connected ||
      target == CompanionPlaybackTarget.details) {
    return navigateToMediaItemDetails(
      context,
      mi,
      onRefresh: onRefresh,
      isOffline: isOffline,
    );
  }

  switch (mi.kind) {
    case MediaKind.collection:
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CollectionDetailScreen(collection: mi, isOffline: isOffline),
        ),
      );
      // If collection was deleted, signal that list refresh is needed
      if (result == true) {
        return MediaNavigationResult.listRefreshNeeded;
      }
      return MediaNavigationResult.navigated;

    case MediaKind.artist:
      await navigateToArtist(context, mi);
      return MediaNavigationResult.navigated;

    case MediaKind.album:
      await navigateToAlbum(context, mi, isOffline: isOffline);
      return MediaNavigationResult.navigated;

    case MediaKind.track:
      // Tracks start playback in their album queue instead of opening a
      // detail surface.
      await playTrackWithAlbumContext(context, mi);
      return MediaNavigationResult.navigated;

    case MediaKind.clip:
    case MediaKind.episode:
      if (mi.kind == MediaKind.episode && shouldOpenEpisodeDetails) {
        return navigateToMediaItemDetails(
          context,
          mi,
          onRefresh: onRefresh,
          isOffline: isOffline,
        );
      }
      final result = await navigateToVideoPlayer(
        context,
        metadata: mi,
        isOffline: isOffline,
      );
      if (result == true && context.mounted) {
        onRefresh?.call(mi);
      }
      return MediaNavigationResult.navigated;

    case MediaKind.movie:
      if (playDirectly && !shouldOpenContinueWatchingDetails) {
        final result = await navigateToVideoPlayer(
          context,
          metadata: mi,
          isOffline: isOffline,
        );
        if (result == true && context.mounted) {
          onRefresh?.call(mi);
        }
        return MediaNavigationResult.navigated;
      }
      return navigateToMediaItemDetails(
        context,
        mi,
        isOffline: isOffline,
        onRefresh: onRefresh,
      );

    case MediaKind.season:
      return navigateToMediaItemDetails(
        context,
        mi,
        isOffline: isOffline,
        onRefresh: onRefresh,
      );

    default:
      return navigateToMediaItemDetails(
        context,
        mi,
        isOffline: isOffline,
        onRefresh: onRefresh,
      );
  }
}

Future<MediaNavigationResult> navigateToMediaItemDetails(
  BuildContext context,
  MediaItem mi, {
  bool isOffline = false,
  void Function(MediaItem source)? onRefresh,
  MediaItem? metadataOverride,
}) async {
  // Catalog stand-ins (Explore tab) must never reach MediaDetailScreen — it
  // hard-requires a server id. Guarded here (not only in navigateToMediaItem)
  // so secondary entry points like card-title clicks are covered too.
  if (mi.isCatalogItem) {
    final catalogItem = mi.catalogItem;
    if (catalogItem == null) return MediaNavigationResult.unsupported;
    await navigateToCatalogItem(context, catalogItem);
    return MediaNavigationResult.navigated;
  }

  final target = mediaDetailNavigationTargetFor(
    mi,
    metadataOverride: metadataOverride,
  );
  final result = await Navigator.push<bool>(
    context,
    mediaDetailRoute(
      metadata: target.metadata,
      isOffline: isOffline,
      initialSeasonIndex: target.initialSeasonIndex,
      initialSeasonId: target.initialSeasonId,
      initialEpisodeId: target.initialEpisodeId,
    ),
  );
  if (result == true && context.mounted) {
    onRefresh?.call(mi);
  }
  return MediaNavigationResult.navigated;
}

/// Opens [ActorMediaScreen] — the filmography of the person [personId] on
/// [serverId]. [personId] is the id `MediaServerClient.fetchPersonMediaPage`
/// takes; [characterName] is the role shown under the name when the person was
/// reached from a title's cast.
Future<void> navigateToPersonMedia(
  BuildContext context, {
  required String personId,
  required String name,
  String? thumbPath,
  String? characterName,
  required String serverId,
  String? serverName,
  required MediaBackend backend,
}) async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ActorMediaScreen(
        actorName: name,
        personId: personId,
        actorThumb: thumbPath,
        characterName: characterName,
        serverId: serverId,
        serverName: serverName,
        backend: backend,
      ),
    ),
  );
}
