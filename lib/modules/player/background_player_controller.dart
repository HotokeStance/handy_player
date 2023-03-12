import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:handy_player/modules/player/audio_handler.dart';
import 'package:handy_player/modules/service_locator.dart';
import 'package:handy_player/shared_preferences_helper.dart';
import 'package:rxdart/rxdart.dart';
import 'package:youtube_api/youtube_api.dart';

class BackgroundPlayerController extends ChangeNotifier {
  BackgroundPlayerController({
    required this.item,
    required this.video,
  });

  final MediaItem item;
  final YouTubeVideo video;

  ProgressBarState progressBarState = ProgressBarState(
    // スライダーの状態値
    current: Duration.zero,
    buffered: Duration.zero,
    total: Duration.zero,
  );

  // ボタン用の音声ファイルの状態値
  AudioState audioState = AudioState.paused;

  /// カウントで制限すればよい？？
  int videoSeekPosition = 0;

  late StreamSubscription
      _playerStateSubscription; // playerStateStreamへのサブスクリプション
  late StreamSubscription _progressBarSubscription;

  final AudioServiceHandler _handler = getIt<AudioServiceHandler>();

  void init() {
    _handler.initPlayer(item);
    _listenToPlaybackState();
    _listenForProgressBarState();
  }

  /* --- SUBSCRIBE --- */
  void _listenToPlaybackState() {
    _playerStateSubscription =
        _handler.playbackState.listen((PlaybackState state) {
      if (isLoadingState(state)) {
        setAudioState(AudioState.loading);
      } else if (isAudioReady(state)) {
        /// 途中再生はここ
        if (videoSeekPosition == 0) {
          Future(() async {
            final seekPosition =
                await SharedPreferencesHelper.getSeekPosition();
            if (seekPosition != '') {
              // [0] : url
              // [1] : duration
              final splited = seekPosition.split(',');
              if (splited[0] == video.url) {
                final timeList = splited[1].split(':');

                final hour = int.parse(timeList[0]) * 3600;
                final minute = int.parse(timeList[1]) * 60;
                final seconds = double.parse(timeList[2]);
                final floored = seconds.floor();

                final sum = hour + minute + floored;
                seek(Duration(seconds: sum));
              }
            }
          });

          videoSeekPosition = 1;
        }
        setAudioState(AudioState.ready);
      } else if (isAudioPlaying(state)) {
        setAudioState(AudioState.playing);
      } else if (isAudioPaused(state)) {
        setAudioState(AudioState.paused);
      } else if (hasCompleted(state)) {
        Future(() async {
          SharedPreferencesHelper.setSeekPosition(
            url: '',
            duration: const Duration(
              hours: 0,
              minutes: 0,
              seconds: 0,
            ),
          );
        });

        setAudioState(AudioState.paused);
      }
    });
  }

  void _listenForProgressBarState() {
    _progressBarSubscription = CombineLatestStream.combine3(
      AudioService.position,
      _handler.playbackState,
      // _handler.mediaItem
      // (Duration current, PlaybackState state, MediaItem mediaItem) =>
      _handler.player.durationStream,
      (Duration current, PlaybackState state, Duration? total) =>
          ProgressBarState(
        current: current,
        buffered: state.bufferedPosition,
        // total: mediaItem?.duraion ?? Duration.zero
        total: total ?? Duration.zero,
      ),
    ).listen((ProgressBarState state) => setProgressBarState(state));
  }

  /* --- UTILITY METHODS --- */
  bool isLoadingState(PlaybackState state) {
    return state.processingState == AudioProcessingState.loading ||
        state.processingState == AudioProcessingState.buffering;
  }

  bool isAudioReady(PlaybackState state) {
    return state.processingState == AudioProcessingState.ready &&
        !state.playing;
  }

  bool isAudioPlaying(PlaybackState state) {
    return state.playing && !hasCompleted(state);
  }

  bool isAudioPaused(PlaybackState state) {
    return !state.playing && !isLoadingState(state);
  }

  bool hasCompleted(PlaybackState state) {
    return state.processingState == AudioProcessingState.completed;
  }

  /* --- PLAYER CONTROL  --- */
  void play() => _handler.play();

  void pause() => _handler.pause();

  void seek(Duration position) => _handler.seek(position);

  void seekPlusTenSecond(Duration currentPosition) {}

  void seekMinusTenSecond(Duration currentPosition) {}

  /// ボタン操作によるListener
  void setAudioState(AudioState state) {
    audioState = state;
    notifyListeners();
  }

  /// プログレスバーによるListener
  void setProgressBarState(ProgressBarState state) {
    progressBarState = state;
    notifyListeners();
  }

  @override
  void dispose() {
    Future(() async {
      SharedPreferencesHelper.setSeekPosition(
        url: video.url,
        duration: progressBarState.current,
      );
    });

    _handler.stop();
    _playerStateSubscription.cancel();
    _progressBarSubscription.cancel();
    super.dispose();
  }
}

class ProgressBarState {
  ProgressBarState({
    required this.current,
    required this.buffered,
    required this.total,
  });

  final Duration current;
  final Duration buffered;
  final Duration total;
}

enum AudioState {
  ready,
  paused,
  playing,
  loading,
}
