import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:os_media_controls/os_media_controls.dart';
import 'package:provider/provider.dart';

import '../../models/companion_remote/remote_command.dart';
import '../../providers/companion_remote_provider.dart';
import '../../services/media_controls_manager.dart';
import '../../services/music/music_playback_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/notification_permission.dart';
import '../../utils/platform_detector.dart';

/// True only while this device is acting as a phone remote for a playing TV.
/// Music owns the global OS media session whenever a local track is loaded.
@visibleForTesting
bool shouldShowRemotePlaybackNotification({
  required bool isAndroidPhone,
  required bool remoteConnected,
  required bool playerActive,
  required bool localMusicLoaded,
}) =>
    isAndroidPhone && remoteConnected && playerActive && !localMusicLoaded;

typedef _RemoteNoticeState = ({
  bool show,
  bool playing,
  String? skipMarker,
  String deviceName,
  bool localMusicLoaded,
});

/// Profile-scoped Android MediaStyle notification for companion-remote video.
/// Reuses the plugin that already runs Plezy's local music notification service,
/// but never advertises an independent local media session at the same time.
///
/// The Android next-track button becomes a contextual Intro/Credits skip button
/// only when the host advertised a real, actionable marker; it cannot perform
/// a blind Select that would unexpectedly pause playback.
class CompanionRemoteMediaNotification extends StatefulWidget {
  const CompanionRemoteMediaNotification({super.key});

  @override
  State<CompanionRemoteMediaNotification> createState() =>
      _CompanionRemoteMediaNotificationState();
}

class _CompanionRemoteMediaNotificationState
    extends State<CompanionRemoteMediaNotification> {
  final MediaControlsManager _controls = MediaControlsManager();
  StreamSubscription<MediaControlEvent>? _events;
  CompanionRemoteProvider? _remote;
  _RemoteNoticeState? _desired;
  Future<void> _serial = Future<void>.value();
  bool _ownsSession = false;

  @override
  void initState() {
    super.initState();
    _events = _controls.controlEvents.listen(_handleControlEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final remote = context.watch<CompanionRemoteProvider>();
    final music = context.watch<MusicPlaybackService>();
    _remote = remote;
    final localMusicLoaded = music.currentTrack != null;
    final visible = shouldShowRemotePlaybackNotification(
      isAndroidPhone: Platform.isAndroid && PlatformDetector.isMobile(context),
      remoteConnected: remote.isRemote && remote.isConnected,
      playerActive: remote.isPlayerActive,
      localMusicLoaded: localMusicLoaded,
    );
    final desired = (
      show: visible,
      playing: remote.isPlayerPlaying,
      skipMarker: remote.remoteSkipMarker,
      deviceName: remote.connectedDevice?.name ?? 'TV',
      localMusicLoaded: localMusicLoaded,
    );
    if (_desired == desired) return;
    _desired = desired;
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    // Native media-control calls must not overtake each other when marker
    // updates and play/pause events arrive during the same background tick.
    _serial = _serial.then((_) => _applyLatest()).catchError((Object e, StackTrace st) {
      appLogger.w('Companion media notification update failed', error: e, stackTrace: st);
    });
  }

  Future<void> _applyLatest() async {
    if (!mounted) return;
    final state = _desired;
    if (state == null) return;

    if (!state.show) {
      if (!_ownsSession) return;
      _ownsSession = false;
      // A local music session is taking over the same OS media-control plugin:
      // don't clear a new track's metadata or stop its foreground service.
      if (state.localMusicLoaded) return;
      await _controls.setBackgroundMode(false);
      await _controls.clear();
      return;
    }

    if (!_ownsSession) {
      // Android 13+: ask for notification permission at the first real TV
      // playback. A denial does not break casting or the in-app remote.
      await NotificationPermission.ensure();
      if (!mounted || _desired?.show != true) return;
    }
    final latest = _desired;
    if (latest == null || !latest.show) return;

    await OsMediaControls.setMetadata(
      MediaMetadata(
        title: 'Plezy on ${latest.deviceName}',
        artist: 'Remote playback',
      ),
    );
    await _controls.setControlsEnabled(
      canPlayPause: true,
      // Android's media-style button uses a skip-next icon. The TV decides
      // whether the active marker is an Intro or Credits skip.
      canGoNext: latest.skipMarker != null,
    );
    await _controls.setBackgroundMode(true);
    _ownsSession = true;
    await _controls.updatePlaybackState(
      isPlaying: latest.playing,
      position: Duration.zero,
      speed: 1,
      force: true,
    );
  }

  void _handleControlEvent(MediaControlEvent event) {
    final state = _desired;
    final remote = _remote;
    if (!_ownsSession || state?.show != true || remote == null ||
        !remote.isRemote || !remote.isConnected || !remote.isPlayerActive) {
      return;
    }
    if (event is PlayEvent || event is PauseEvent || event is TogglePlayPauseEvent) {
      remote.sendCommand(RemoteCommandType.playPause);
    } else if (event is NextTrackEvent) {
      // Avoid blind Select/Enter: it toggles playback when no skip is focused.
      switch (remote.remoteSkipMarker) {
        case 'intro':
          remote.sendCommand(RemoteCommandType.skipIntro);
        case 'credits':
          remote.sendCommand(RemoteCommandType.skipCredits);
      }
    }
  }

  @override
  void dispose() {
    _desired = null;
    unawaited(_events?.cancel());
    _serial = _serial.then((_) async {
      if (_ownsSession) {
        await _controls.setBackgroundMode(false);
        await _controls.clear();
        _ownsSession = false;
      }
      _controls.dispose();
    }).catchError((Object e, StackTrace st) {
      appLogger.w('Companion media notification cleanup failed', error: e, stackTrace: st);
      _controls.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
