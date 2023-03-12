import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart' as avpb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:handy_player/modules/player/background_player_controller.dart';
import 'package:handy_player/modules/search/search_state.dart';
import 'package:handy_player/modules/search/search_state_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart' as provider;
import 'package:video_player/video_player.dart';
import 'package:youtube_api/youtube_api.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final searchStateNotifier =
    StateNotifierProvider<SearchStateNotifier, SearchState>((ref) {
  return SearchStateNotifier(ref: ref);
});

class SearchScreen extends HookConsumerWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(searchStateNotifier);

    return Scaffold(
      appBar: AppBar(
        title: _autoCompleteWidget(context, ref),
      ),
      body: _youtubeListWidget(context, ref),
    );
  }

  Widget _autoCompleteWidget(BuildContext context, WidgetRef ref) {
    final searchHistories = ref.watch(searchStateNotifier).searchHistories;
    return Autocomplete<String>(
      // optionsViewBuilder: (context, onSelected, iterable) {
      //   return Material(
      //     child: ListView.builder(
      //       itemCount: searchHistories.length,
      //       itemBuilder: (context, index) {
      //         /// TODO: 以下なぜか動かない
      //         //  final text = iterable.elementAt(index);
      //         final text = searchHistories[index];
      //         return InkWell(
      //           onTap: () async {
      //             await _searchYoutubeQuery(text);
      //           },
      //           child: ListTile(
      //             trailing: IconButton(
      //               onPressed: () {
      //                 setState(() {
      //                   searchHistories.remove(text);
      //                 });
      //               },
      //               icon: const Icon(Icons.close),
      //             ),
      //             title: Text(text),
      //           ),
      //         );
      //       },
      //     ),
      //   );
      // },
      onSelected: (value) async {
        FocusScope.of(context).unfocus();
        await ref
            .read(searchStateNotifier.notifier)
            .saveSearchHistories(searchWord: value);
        await ref.read(searchStateNotifier.notifier).searchYoutubeQuery(value);
      },
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text == '') {
          return searchHistories;
        }
        return searchHistories.where((element) {
          return element.contains(textEditingValue.text);
        });
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          onFieldSubmitted: (value) async {
            debugPrint('onFieldSubmitted');
            await ref
                .read(searchStateNotifier.notifier)
                .saveSearchHistories(searchWord: value);
            debugPrint('save');
            await ref
                .read(searchStateNotifier.notifier)
                .searchYoutubeQuery(value);
          },
          decoration: InputDecoration(
            suffixIcon: InkWell(
              onTap: () {
                textEditingController.clear();
              },
              child: const Icon(Icons.close),
            ),
          ),
        );
      },
    );
  }

  Widget _youtubeListWidget(BuildContext context, WidgetRef ref) {
    final searchVideoResults =
        ref.watch(searchStateNotifier).searchVideoResults;

    final isYoutubeSearchError =
        ref.watch(searchStateNotifier).isYoutubeSearchError;

    if (isYoutubeSearchError) {
      return const Center(child: Text('検索に失敗しました'));
    }

    if (searchVideoResults.isEmpty) {
      return const Center(child: Text('動画を検索'));
    }

    return ListView.builder(
      itemCount: searchVideoResults.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: VideoWidget(
            video: searchVideoResults[index],
          ),
        );
      },
    );
  }
}

class VideoWidget extends ConsumerStatefulWidget {
  const VideoWidget({
    Key? key,
    required this.video,
  }) : super(key: key);

  final YouTubeVideo video;

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends ConsumerState<VideoWidget> {
  String downloading = 'ダウンロード';

  @override
  Widget build(BuildContext context) {
    const snackBar = SnackBar(content: Text('Process Complete'));
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final result = await showDialog(
              context: context,
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setState) {
                    _downloadVideo(String youTubeLink) async {
                      setState(() {
                        downloading = '待機中';
                      });

                      final yt = YoutubeExplode();
                      final video = await yt.videos.get(youTubeLink);

                      // Get the video manifest.
                      final manifest = await yt.videos.streamsClient
                          .getManifest(youTubeLink);
                      final streams = manifest.muxed;
                      final audio = streams.first;
                      final audioStream = yt.videos.streamsClient.get(audio);
                      final fileName =
                          '${video.title}.${audio.container.name.toString()}'
                              .replaceAll(r'\', '')
                              .replaceAll('/', '')
                              .replaceAll('*', '')
                              .replaceAll('?', '')
                              .replaceAll('"', '')
                              .replaceAll('<', '')
                              .replaceAll('>', '')
                              .replaceAll('|', '');

                      final dir = await getApplicationDocumentsDirectory();
                      final path = dir.path;
                      final directory = Directory('$path/video/');
                      await directory.create(recursive: true);
                      final file = File('$path/video/$fileName');
                      final output =
                          file.openWrite(mode: FileMode.writeOnlyAppend);
                      var len = audio.size.totalBytes;
                      var count = 0;
                      var msg =
                          'Downloading ${video.title}.${audio.container.name}';
                      stdout.writeln(msg);
                      await for (final data in audioStream) {
                        count += data.length;
                        var progress = ((count / len) * 100).ceil();
                        downloading = progress.toString();
                        setState(() {});
                        output.add(data);
                      }
                      await output.flush();
                      await output.close();

                      setState(() {
                        downloading = 'ダウンロード';
                      });
                    }

                    _newDownloadVideo(String youTubeLink) async {
                      final yt = YoutubeExplode();
                      try {
                        final video = await yt.videos.get(youTubeLink);

                        final streamManifest = await yt.videos.streamsClient
                            .getManifest(youTubeLink);

                        final audioStream =
                            streamManifest.audioOnly.withHighestBitrate();

                        final videoStream = streamManifest.videoOnly.firstWhere(
                            (element) =>
                                element.videoQuality == VideoQuality.high720);

                        final fileName = video.title
                            .replaceAll(r'\', '')
                            .replaceAll('/', '')
                            .replaceAll('*', '')
                            .replaceAll('?', '')
                            .replaceAll('"', '')
                            .replaceAll('<', '')
                            .replaceAll('>', '')
                            .replaceAll('|', '')
                            .replaceAll('#', '')
                            .replaceAll(' ', '')
                            .replaceAll('　', '');

                        final dir = await getApplicationDocumentsDirectory();
                        final path = '${dir.path}/video/';
                        final directory = Directory(path);
                        await directory.create(recursive: true);

                        String ffmpegCommand = '';
                        if (Platform.isAndroid) {
                          ffmpegCommand =
                              '-i ${videoStream.url} -i ${audioStream.url} -c:v copy $path$fileName.mp4';
                        } else {
                          ffmpegCommand =
                              '-i ${videoStream.url} -i ${audioStream.url} -c:v copy -c:a aac $path$fileName.mp4';
                        }

                        await FFmpegKit.executeAsync(ffmpegCommand, (session) {
                          debugPrint('============================');
                          debugPrint('変換実行');
                          debugPrint('============================');
                        }, (log) {
                          debugPrint('============================');
                          debugPrint('log::::::::${log.getSessionId()}');
                          debugPrint('log::::::::${log.getMessage()}');
                          debugPrint('============================');
                        }, (staistics) {
                          debugPrint('============================');
                          debugPrint('staistics::::::::$staistics');
                          debugPrint('============================');
                        });
                      } catch (e) {
                        debugPrint('実行エラー$e');
                        await _downloadVideo(youTubeLink);
                      } finally {
                        yt.close();
                      }
                    }

                    return SimpleDialog(
                      title: Text(widget.video.title),
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, PlayStatus.streaming);
                          },
                          child: const Text('再生'),
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        // ElevatedButton(
                        //   onPressed: () async {
                        //     await _newDownloadVideo(widget.video.url);
                        //     //await _downloadVideo(widget.video.url);
                        //     Navigator.pop(context, PlayStatus.download);
                        //   },
                        //   child: Text(downloading),
                        // ),
                      ],
                    );
                  },
                );
              },
            );

            if (result != null) {
              if (result == PlayStatus.streaming) {
                const snackBar = SnackBar(content: Text('URLを再生できませんでした'));
                // AudioStreamの取得
                final audioStreamInfo = await ref
                    .read(searchStateNotifier.notifier)
                    .getAudioOnlyStreamInfo(widget.video.url);
                // VideoStreamの取得
                final videoStreamInfo = await ref
                    .read(searchStateNotifier.notifier)
                    .getVideoOnlyStreamInfo(widget.video.url);
                if (audioStreamInfo == null) {
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return _BackgroundPlayer(
                        video: widget.video,
                        audioOnlyStreamInfo: audioStreamInfo,
                        videoOnlyStreamInfo: videoStreamInfo,
                      );
                    },
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              }
            }
          },
          child: Column(
            children: [
              Text(widget.video.title),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CachedNetworkImage(
                      imageUrl: widget.video.thumbnail.high.url ?? '',
                      width: 120,
                      height: 120,
                      errorWidget: (a, b, c) => const Icon(Icons.error)),
                  Flexible(child: Text(widget.video.channelTitle)),
                ],
              ),
            ],
          ),
        ),
        const Divider(
          color: Colors.white,
        )
      ],
    );
  }
}

class _BackgroundPlayer extends StatelessWidget {
  const _BackgroundPlayer({
    Key? key,
    required this.video,
    required this.audioOnlyStreamInfo,
    required this.videoOnlyStreamInfo,
  }) : super(key: key);

  final YouTubeVideo video;
  final AudioOnlyStreamInfo audioOnlyStreamInfo;
  final VideoOnlyStreamInfo? videoOnlyStreamInfo;

  @override
  Widget build(BuildContext context) {
    final mediaItem = MediaItem(
      id: audioOnlyStreamInfo.url.toString(),
      album: "",
      title: video.title,
      artist: video.channelTitle,
      artUri: Uri.parse('${video.thumbnail.high.url}'),
    );

    debugPrint('initinit');

    return provider.ChangeNotifierProvider(
      create: (_) =>
          BackgroundPlayerController(item: mediaItem, video: video)..init(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              videoOnlyStreamInfo == null
                  ? const SizedBox(
                      width: double.infinity,
                      height: 300,
                      child: Center(
                        child: Text('動画がありません'),
                      ),
                    )
                  : _VideoPlayerWidget(
                      video: video,
                      videoOnlyStreamInfo: videoOnlyStreamInfo!,
                    ),
              _AudioControlWidget(
                video: video,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  const _VideoPlayerWidget({
    Key? key,
    required this.video,
    required this.videoOnlyStreamInfo,
  }) : super(key: key);

  final YouTubeVideo video;
  final VideoOnlyStreamInfo videoOnlyStreamInfo;

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController videoPlayerController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    setState(() {
      isLoading = true;
    });

    Future(() async {
      videoPlayerController = VideoPlayerController.contentUri(
          widget.videoOnlyStreamInfo.url,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      await videoPlayerController.initialize();
      setState(() {
        isLoading = false;
      });
    });
  }

  Future<void> playVideo() async {
    setState(() {
      isLoading = true;
    });
    if (!videoPlayerController.value.isPlaying) {
      await videoPlayerController.play();
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> pauseVideo() async {
    setState(() {
      isLoading = true;
    });
    if (videoPlayerController.value.isPlaying) {
      await videoPlayerController.pause();
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> seekToVideo(Duration position) async {
    setState(() {
      isLoading = true;
    });
    await videoPlayerController.seekTo(position);

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('widgetBuildwidgetBuildwidgetBuildwidgetBuild');

    return provider.Consumer<BackgroundPlayerController>(
      builder: (context, value, _) {
        final play = value.audioState == AudioState.playing;
        final paused = value.audioState == AudioState.ready ||
            value.audioState == AudioState.paused;
        // Future(() async {
        //   seekToVideo(value.progressBarState.current);
        // });

        Future(() async {
          final a = videoPlayerController.position.toString();
        });

        if (paused) {
          Future(() async {
            pauseVideo();
          });
        }
        if (play) {
          Future(() async {
            playVideo();
          });
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Column(
                children: [
                  AspectRatio(
                    aspectRatio: videoPlayerController.value.aspectRatio,
                    child: VideoPlayer(videoPlayerController),
                  ),
                  Text('${value.audioState}'),
                ],
              ),
              if (isLoading) const CircularProgressIndicator(),
            ],
          ),
        );
      },
    );
  }
}

class _AudioControlWidget extends StatelessWidget {
  const _AudioControlWidget({Key? key, required this.video}) : super(key: key);

  final YouTubeVideo video;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          provider.Selector(
            selector:
                (BuildContext context, BackgroundPlayerController controller) {
              return controller.progressBarState;
            },
            builder: (BuildContext context, ProgressBarState state, _) {
              return avpb.ProgressBar(
                progress: state.current,
                buffered: state.buffered,
                total: state.total,
                onSeek: (Duration position) =>
                    context.read<BackgroundPlayerController>().seek(position),
              );
            },
          ),
          provider.Selector(
            selector:
                (BuildContext ctx, BackgroundPlayerController controller) =>
                    controller.audioState,
            builder: (BuildContext context, AudioState state, _) {
              switch (state) {
                case AudioState.loading:
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      height: 32,
                      width: 32,
                      child: CircularProgressIndicator(),
                    ),
                  );
                case AudioState.ready:
                case AudioState.paused:
                  return IconButton(
                    onPressed: () =>
                        context.read<BackgroundPlayerController>().play(),
                    icon: const Icon(Icons.play_arrow),
                    iconSize: 32.0,
                  );
                case AudioState.playing:
                  return IconButton(
                    onPressed: () =>
                        context.read<BackgroundPlayerController>().pause(),
                    icon: const Icon(Icons.pause),
                    iconSize: 32.0,
                  );
                default:
                  return const SizedBox(
                    height: 32,
                    width: 32,
                  );
              }
            },
          ),
        ],
      ),
    );
  }
}

enum PlayStatus {
  streaming,
  download,
}
