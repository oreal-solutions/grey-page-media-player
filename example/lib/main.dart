import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:npxl_video/npxl_video.dart' as npxl;
import 'package:grey_page_media_player/grey_page_media_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Grey Page Media Player example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isInitialising = true;
  String errorThrownWhileInitialising = '';

  final mediaPlayer = MediaPlayer.makeInstance();

  String get playbackPosition =>
      '${mediaPlayer.seekPosition}/${mediaPlayer.videoDuration}';

  @override
  void initState() {
    super.initState();

    makeTestVideo().then((videoReader) async {
      await mediaPlayer.initialiseWith(videoReader);
      setState(() {
        isInitialising = false;
      });
    }).onError((error, stackTrace) {
      setState(() {
        errorThrownWhileInitialising = '$error\n$stackTrace';
      });
    });
  }

  @override
  void dispose() {
    mediaPlayer.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: isInitialising
          ? Column(
              children: [
                Text('Is Initialising'),
                Text(
                  errorThrownWhileInitialising,
                  style: TextStyle(color: Colors.red),
                )
              ],
            )
          : Column(
              children: [
                Text(playbackPosition),
                Text(mediaPlayer.state.toString()),
                Divider(
                  height: 10,
                  thickness: 0,
                ),
                MediaPlayerView(
                  initialisedMediaPlayer: mediaPlayer,
                  size: Size(MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height * .7),
                  onPostRender: () {
                    // To show the latest playback position and media player state.
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      setState(() {});
                    });
                  },
                ),
                Divider(
                  height: 10,
                  thickness: 0,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: mediaPlayer.play,
                    ),
                    IconButton(
                      icon: Icon(Icons.pause),
                      onPressed: mediaPlayer.pause,
                    ),
                    IconButton(
                      icon: Icon(Icons.stop),
                      onPressed: mediaPlayer.stop,
                    ),
                    IconButton(
                      icon: Icon(Icons.replay),
                      onPressed: mediaPlayer.replay,
                    ),
                  ],
                )
              ],
            ),
    );
  }

  Future<VideoReader> makeTestVideo() async {
    // Generates a simple 4 seconds test video with 4 media pages where
    // each media page is 1 seconds long. Each media page has a different
    // color.
    //
    // In each media page we draw a square path. The first media page has
    // the square at its top left corner. The second media page has the
    // square at its top right corner, and so on.
    final oneSecondInMillis = 1000;
    final viewport = npxl.Viewport(
      height: 20,
      width: 20,
      topLeftCorner: npxl.Point(dx: 0, dy: 0),
    );

    npxl.PathPoint makePathPointAt(double dx, double dy) {
      return npxl.PathPoint(
        coordinates: npxl.Point(dx: dx, dy: dy),
        pressure: 1,
      );
    }

    Iterable<npxl.PathPoint> squarePathAtTopLeftCorner(
        double cornerX, double cornerY) {
      return [
        makePathPointAt(0 + cornerX, 0 + cornerY),
        makePathPointAt(10 + cornerX, 0 + cornerY),
        makePathPointAt(10 + cornerX, 10 + cornerY),
        makePathPointAt(0 + cornerX, 10 + cornerY),
      ];
    }

    npxl.MediaPageBuilder makeMediaPageBuilder(
        {@required Color backgroundColor,
        @required Iterable<npxl.PathPoint> points,
        @required int mediaPageNumber}) {
      return npxl.MediaPageBuilder()
        ..setMediaPageDurationInMillis(oneSecondInMillis)
        ..setMediaPageNumber(mediaPageNumber)
        ..setVectorFrame(npxl.RenderingInstructions(
          viewport: viewport,
          backgroundColor: npxl.Color(value: backgroundColor.value),
          paths: [
            npxl.Path(
              color: npxl.Color(value: Colors.red.value),
              strokeWidth: 2,
              points: points,
            )
          ],
        ));
    }

    final mediaPageBuilders = [
      makeMediaPageBuilder(
          backgroundColor: Colors.blue,
          points: squarePathAtTopLeftCorner(0, 0),
          mediaPageNumber: 1),
      makeMediaPageBuilder(
          backgroundColor: Colors.green,
          points: squarePathAtTopLeftCorner(10, 0),
          mediaPageNumber: 2),
      makeMediaPageBuilder(
          backgroundColor: Colors.orange,
          points: squarePathAtTopLeftCorner(10, 10),
          mediaPageNumber: 3),
      makeMediaPageBuilder(
          backgroundColor: Colors.purple,
          points: squarePathAtTopLeftCorner(0, 10),
          mediaPageNumber: 4),
    ];

    final mediaPageDataRanges = <npxl.DataRange>[];
    final mediaPagesBinaryData = <int>[];

    int lastEndIndex = 0;
    for (var builder in mediaPageBuilders) {
      final binaryData = await builder.build();
      mediaPagesBinaryData.addAll(binaryData);

      mediaPageDataRanges.add(npxl.DataRange(
          start: lastEndIndex, end: lastEndIndex + binaryData.length));
      lastEndIndex = lastEndIndex + binaryData.length;
    }

    final videoBuilder = npxl.VideoBuilder();
    videoBuilder.setMediaPageDataRanges(mediaPageDataRanges);
    videoBuilder.setMediaPagesInputStream(
        npxl.InMemoryRandomAccessByteInputStream(
            Uint8List.fromList(mediaPagesBinaryData)));
    videoBuilder.setVideoDurationInMillis(4 * oneSecondInMillis);

    // We can write test video to file if we want.
    final testVideo =
        npxl.InMemoryRandomAccessByteInputStream(await videoBuilder.build());
    print("Test video size in bytes = ${testVideo.data.lengthInBytes}");

    return StreamVideoReader(testVideo);
  }
}
