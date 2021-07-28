import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:npxl_video/npxl_video.dart' as npxl;
import 'package:grey_page_media_player/grey_page_media_player.dart';

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
      {@required int backgroundColor,
      @required Iterable<npxl.PathPoint> points}) {
    return npxl.MediaPageBuilder()
      ..setVectorFrame(npxl.RenderingInstructions(
        viewport: viewport,
        backgroundColor: npxl.Color(value: backgroundColor),
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
      backgroundColor: Colors.blue.value,
      points: squarePathAtTopLeftCorner(0, 0),
    ),
    makeMediaPageBuilder(
      backgroundColor: Colors.green.value,
      points: squarePathAtTopLeftCorner(10, 0),
    ),
    makeMediaPageBuilder(
      backgroundColor: Colors.orange.value,
      points: squarePathAtTopLeftCorner(10, 10),
    ),
    makeMediaPageBuilder(
      backgroundColor: Colors.purple.value,
      points: squarePathAtTopLeftCorner(0, 10),
    ),
  ];

  final mediaPageHeaders = <npxl.MediaPageHeader>[];
  final mediaPagesBinaryData = <int>[];

  int lastEndIndex = 0;
  for (var i = 0; i < mediaPageBuilders.length; i++) {
    final builder = mediaPageBuilders[i];

    final binaryData = await builder.build();
    mediaPagesBinaryData.addAll(binaryData);

    mediaPageHeaders.add(npxl.MediaPageHeader(
      mediaPageDataRange: npxl.DataRange(
          start: lastEndIndex, end: lastEndIndex + binaryData.length),
      pageDurationInMillis: oneSecondInMillis,
      mediaPageNumber: i,
    ));
    lastEndIndex = lastEndIndex + binaryData.length;
  }

  final videoBuilder = npxl.VideoBuilder();
  videoBuilder.setMediaPageHeaders(mediaPageHeaders);
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
