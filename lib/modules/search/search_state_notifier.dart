import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:handy_player/modules/search/search_state.dart';
import 'package:handy_player/shared_preferences_helper.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:youtube_api/youtube_api.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class SearchStateNotifier extends StateNotifier<SearchState> {
  SearchStateNotifier({required this.ref}) : super(const SearchState()) {
    init();
  }

  final Ref ref;

  Future<void> init() async {
    final searchHistories = await SharedPreferencesHelper.getSearchHistories();
    if (searchHistories.isNotEmpty) {
      searchYoutubeQuery(searchHistories.first);
    }

    state = state.copyWith(
      searchHistories: searchHistories,
    );
  }

  /// Youtube検索
  Future<void> searchYoutubeQuery(String text) async {
    try {
      state = state.copyWith(
        isYoutubeSearchError: false,
      );
      final apiKey = dotenv.env['GOOGLE_API_KEY'];
      YoutubeAPI ytApi = YoutubeAPI(apiKey!, maxResults: 50, type: 'video');
      final videoResult = await ytApi.search(text, type: 'video');
      state = state.copyWith(
        searchVideoResults: videoResult,
      );
    } catch (_) {
      state = state.copyWith(
        isYoutubeSearchError: true,
      );
    }
  }

  /// 検索ワード保存
  Future<void> saveSearchHistories({required String searchWord}) async {
    try {
      if (state.searchHistories.contains(searchWord)) {
        final List<String> searchHistories = List.from(state.searchHistories);
        searchHistories.remove(searchWord);
        searchHistories.insert(0, searchWord);
        await SharedPreferencesHelper.setSearchHistories(searchHistories);

        state = state.copyWith(
          searchHistories: searchHistories,
        );
        return;
      }
      final List<String> searchHistories = List.from(state.searchHistories);
      searchHistories.insert(0, searchWord);

      await SharedPreferencesHelper.setSearchHistories(searchHistories);

      state = state.copyWith(
        searchHistories: searchHistories,
      );
    } catch (_) {
      debugPrint('Error');
    }
  }

  void clearSearchWord() {
    state = state.copyWith(
      searchBoxController: TextEditingController(),
    );
  }

  /// AudionStreamを返す
  Future<AudioOnlyStreamInfo?> getAudioOnlyStreamInfo(String url) async {
    final yt = YoutubeExplode();
    try {
      final streamManifest = await yt.videos.streamsClient.getManifest(url);

      final audioStream = streamManifest.audioOnly.withHighestBitrate();

      return audioStream;
    } catch (_) {
      debugPrint('audioError');
      return null;
    }
  }

  /// AudionStreamを返す
  Future<VideoOnlyStreamInfo?> getVideoOnlyStreamInfo(String url) async {
    final yt = YoutubeExplode();
    try {
      final streamManifest = await yt.videos.streamsClient.getManifest(url);

      final videoStream = streamManifest.videoOnly.firstWhere(
          (element) => element.videoQuality == VideoQuality.high720);
      return videoStream;
    } catch (_) {
      debugPrint('videoError');
      return null;
    }
  }
}
