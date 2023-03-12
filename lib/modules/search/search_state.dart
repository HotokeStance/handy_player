import 'package:flutter/cupertino.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:youtube_api/youtube_api.dart';

part 'search_state.freezed.dart';

enum PlayButtonState {
  paused,
  playing,
  loading,
}

@freezed
class SearchState with _$SearchState {
  const factory SearchState({
    @Default(<YouTubeVideo>[]) List<YouTubeVideo> searchVideoResults,
    @Default(<String>[]) List<String> searchHistories,
    @Default(false) bool isYoutubeSearchError,
    @Default(<String>[]) List<String> searchTes,
    TextEditingController? searchBoxController,
    @Default(PlayButtonState.paused) PlayButtonState playButtonState,
  }) = _SearchState;
}
