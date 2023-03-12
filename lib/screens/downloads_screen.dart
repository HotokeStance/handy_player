import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_player/widget/chewie_widget.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  _DownloadsScreenState createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<FileSystemEntity> videos = [];

  @override
  void initState() {
    super.initState();
    Future(() async {
      // ダウンロードした動画を取得
      await _getDownloads();
    });
  }

  Future<void> _getDownloads() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = dir.path;
    final videoDirectory = Directory('$path/video/');

    videos = videoDirectory.listSync(recursive: true, followLinks: false);
    for (final item in videos) {
      debugPrint('ファイル::::$item');
    }

    setState(() {
      videos;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
      ),
      body: ListView.builder(
        itemCount: videos.length,
        itemBuilder: (context, index) {
          return VideoWidget(fileSystemEntity: videos[index]);
        },
      ),
    );
  }
}

class VideoWidget extends StatefulWidget {
  const VideoWidget({Key? key, required this.fileSystemEntity})
      : super(key: key);

  final FileSystemEntity fileSystemEntity;

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: ChewieWidget(
        fileSystemEntity: widget.fileSystemEntity,
      ),
    );
  }
}
