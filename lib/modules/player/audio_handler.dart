import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';

/// システムにオーディオを流す

Future<AudioServiceHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => AudioServiceHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mycompany.myapp.audio',
      androidNotificationChannelName: 'Audio Service Demo',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class AudioServiceHandler extends BaseAudioHandler {
  final AudioPlayer player = AudioPlayer();
  late AudioPlayer subPlayer1;
  late AudioPlayer subPlayer2;

  Future<void> initPlayer(MediaItem item) async {
    try {
      _notifyAudioHandlerAboutPlaybackEvents();
      mediaItem.add(item);
      player.setAudioSource(AudioSource.uri(Uri.parse(item.id)));
    } catch (e) {
      debugPrint('ERROR OCCURED:$e');
    }
  }

  /// Streamサブスクライブ処理
  /// just_audioの状態をAudioServiceに流す
  void _notifyAudioHandlerAboutPlaybackEvents() {
    player.playbackEventStream.listen((event) {
      final playing = player.playing;

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
          },
          androidCompactActionIndices: const [0, 1, 3],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[player.processingState]!,
          playing: playing,
          updatePosition: player.position,
          bufferedPosition: player.bufferedPosition,
          speed: player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });
  }

  /// AudioControl
  @override
  Future<void> play() async {
    player.play();
  }

  @override
  Future<void> pause() async {
    player.pause();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() {
    player.stop();
    return super.stop();
  }
}
