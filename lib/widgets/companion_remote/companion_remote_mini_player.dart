import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../media/media_item.dart';
import '../../models/companion_remote/remote_command.dart';
import '../../navigation/profile_navigation_scope.dart';
import '../../providers/companion_remote_provider.dart';
import '../../screens/companion_remote/mobile_remote_screen.dart';
import '../../services/music/music_playback_service.dart';
import '../../widgets/music/mini_player.dart';
import 'mobile_remote_shortcut.dart';

/// Only show remote playback on a browsing screen of an Android phone.
/// The existing local music mini-player keeps priority over this surface.
@visibleForTesting
bool shouldShowCompanionRemoteMiniPlayer({
  required bool androidPhone,
  required bool routeVisible,
  required bool remoteConnected,
  required bool playerActive,
  required bool localMusicLoaded,
}) =>
    androidPhone &&
    routeVisible &&
    remoteConnected &&
    playerActive &&
    !localMusicLoaded;

/// The progress is display-only: seeking is handled by the remote itself.
@visibleForTesting
double companionMiniPlayerProgress(Duration position, Duration duration) {
  final total = duration.inMilliseconds;
  if (total <= 0) return 0;
  return (position.inMilliseconds / total).clamp(0.0, 1.0);
}

String _formatRemoteTime(Duration time) {
  final seconds = time.inSeconds < 0 ? 0 : time.inSeconds;
  final minutes = (seconds ~/ 60) % 60;
  final remaining = (seconds % 60).toString().padLeft(2, '0');
  final hours = seconds ~/ 3600;
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$remaining'
      : '$minutes:$remaining';
}

/// In-app bar mounted above the profile navigator, just like the music
/// mini-player. It follows page changes but hides during playback/modal
/// routes, when the remote is disconnected and while local music is playing.
class CompanionRemoteMiniPlayerOverlay extends StatelessWidget {
  const CompanionRemoteMiniPlayerOverlay({super.key, required this.routeVisible});

  final ValueListenable<bool> routeVisible;

  void _openRemote(BuildContext context) {
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
    if (!MobileCompanionRemoteShortcut.isSupported(context)) {
      return const SizedBox.shrink();
    }

    final remote = context.watch<CompanionRemoteProvider>();
    final musicLoaded = context.select<MusicPlaybackService, bool>(
      (music) => music.currentTrack != null,
    );
    final (navBottom, navStart) = context.select<MiniPlayerInsetController, (double, double)>(
      (insets) => (insets.bottomInset, insets.startInset),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: routeVisible,
      builder: (context, visible, _) {
        if (!shouldShowCompanionRemoteMiniPlayer(
          androidPhone: true,
          routeVisible: visible,
          remoteConnected: remote.isRemote && remote.isConnected,
          playerActive: remote.isPlayerActive,
          localMusicLoaded: musicLoaded,
        )) {
          return const SizedBox.shrink();
        }

        final safePadding = MediaQuery.paddingOf(context);
        final isLtr = Directionality.of(context) == TextDirection.ltr;
        final horizontalStart = isLtr ? safePadding.left : safePadding.right;
        final horizontalEnd = isLtr ? safePadding.right : safePadding.left;
        final bottom = 12 + (navBottom > 0 ? navBottom : safePadding.bottom);

        return Stack(
          children: [
            PositionedDirectional(
              start: 12 + (navStart > horizontalStart ? navStart : horizontalStart),
              end: 12 + horizontalEnd,
              bottom: bottom,
              child: _CompanionRemoteMiniCard(
                remote: remote,
                onOpenRemote: () => _openRemote(context),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CompanionRemoteMiniCard extends StatelessWidget {
  const _CompanionRemoteMiniCard({required this.remote, required this.onOpenRemote});

  final CompanionRemoteProvider remote;
  final VoidCallback onOpenRemote;

  void _skip() {
    if (!remote.isRemote || !remote.isConnected || !remote.isPlayerActive) return;
    switch (remote.remoteSkipMarker) {
      case 'intro':
        remote.sendCommand(RemoteCommandType.skipIntro);
      case 'credits':
        remote.sendCommand(RemoteCommandType.skipCredits);
    }
  }

  void _togglePlayback() {
    if (!remote.isRemote || !remote.isConnected || !remote.isPlayerActive) return;
    remote.sendCommand(
      remote.isPlayerPlaying ? RemoteCommandType.pause : RemoteCommandType.play,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final position = remote.remotePosition;
    final duration = remote.remoteDuration;
    final showSkip = remote.remoteSkipMarker == 'intro' || remote.remoteSkipMarker == 'credits';
    final skipLabel = remote.remoteSkipMarker == 'credits' ? 'Skip Credits' : 'Skip Intro';
    final title = remote.remoteMediaTitle?.trim();
    final secondary = remote.remoteMediaSubtitle?.trim();
    final device = remote.connectedDevice?.name ?? 'TV';
    final detail = <String>[
      if (secondary != null && secondary.isNotEmpty) secondary,
      if (duration > Duration.zero)
        '${_formatRemoteTime(position)} / ${_formatRemoteTime(duration)}'
      else
        'Playing on $device',
    ].join(' · ');

    return Material(
      key: const ValueKey('companion_remote_mini_player'),
      color: colors.surfaceContainerHigh,
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(Icons.cast_connected_rounded, size: 26, color: colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: InkWell(
                    onTap: onOpenRemote,
                    child: SizedBox.expand(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title == null || title.isEmpty ? 'Playing on $device' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('companion_remote_mini_play_pause'),
                  onPressed: _togglePlayback,
                  tooltip: remote.isPlayerPlaying ? 'Pause on TV' : 'Play on TV',
                  icon: Icon(remote.isPlayerPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                if (showSkip)
                  TextButton(
                    key: const ValueKey('companion_remote_mini_skip'),
                    onPressed: _skip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      minimumSize: const Size(48, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(skipLabel, style: const TextStyle(fontSize: 11)),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          if (duration > Duration.zero)
            LinearProgressIndicator(
              value: companionMiniPlayerProgress(position, duration),
              minHeight: 3,
              backgroundColor: colors.surfaceContainerLowest,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
        ],
      ),
    );
  }
}
