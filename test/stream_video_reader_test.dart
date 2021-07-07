import 'dart:typed_data';

import 'package:grey_page_media_player/src/readers/stream_video_reader.dart';
import 'package:grey_page_media_player/src/readers/video_reader.dart';
import 'package:grey_page_media_player/src/void_extensions.dart';
import 'package:npxl_video/generated/npxl_video.pb.dart';
import 'package:npxl_video/npxl_video.dart';

import 'package:test/test.dart';

void main() {
  InMemoryRandomAccessByteInputStream testVideo;

  setUp(() async {
    final mediaPageBuilders = [
      MediaPageBuilder()
        ..setMediaPageDurationInMillis(Duration(seconds: 2).inMilliseconds)
        ..setMediaPageNumber(1),
      MediaPageBuilder()
        ..setMediaPageDurationInMillis(Duration(seconds: 3).inMilliseconds)
        ..setCompressedAudioData(Uint8List.fromList([0xbb, 0xcc]))
        ..setMediaPageNumber(2),
      MediaPageBuilder()
        ..setMediaPageDurationInMillis(Duration(seconds: 1).inMilliseconds)
        ..setCompressedAudioData(Uint8List.fromList([0xdd, 0xee]))
        ..setMediaPageNumber(3),
      // <-- 1 missing media page here
      MediaPageBuilder()
        ..setMediaPageDurationInMillis(Duration(seconds: 4).inMilliseconds)
        ..setMediaPageNumber(5),
    ];

    final mediaPageDataRanges = <DataRange>[];
    final mediaPagesBinaryData = <int>[];

    int lastEndIndex = 0;
    for (var builder in mediaPageBuilders) {
      final binaryData = await builder.build();
      mediaPagesBinaryData.addAll(binaryData);

      mediaPageDataRanges.add(DataRange(
          start: lastEndIndex, end: lastEndIndex + binaryData.length));
      lastEndIndex = lastEndIndex + binaryData.length;
    }

    // Add the corrupted media page,
    mediaPagesBinaryData.addAll([0xaa, 0xbb, 0xcc]);
    mediaPageDataRanges
        .add(DataRange(start: lastEndIndex, end: lastEndIndex + 3));

    final videoBuilder = VideoBuilder();
    videoBuilder.setAudioProperties(AudioProperties(samplingRate: 48000));
    videoBuilder.setMediaPageDataRanges(mediaPageDataRanges);
    videoBuilder.setMediaPagesInputStream(InMemoryRandomAccessByteInputStream(
        Uint8List.fromList(mediaPagesBinaryData)));
    // Corrupted and missing Media Pages are given the same length as the last valid
    // media page before them.
    videoBuilder.setVideoDurationInMillis(Duration(seconds: 15).inMilliseconds);

    testVideo = InMemoryRandomAccessByteInputStream(await videoBuilder.build());
  });

  group("StreamVideoReader Tests", () {
    VideoReader instance;
    setUp(() async {
      instance = StreamVideoReader(testVideo);
      await instance.initialise();
    });

    test("Should read the correct audio properties", () async {
      expect(await instance.getAudioProperties(),
          AudioProperties(samplingRate: 48000));
    });
    test("Should read the correct video duration", () async {
      expect(await instance.getVideoDuration(), Duration(seconds: 15));
    });

    group("getMediaPagesInRange(inclusiveStart, exclusiveEnd)", () {
      test(
          "Should return MediaPages at the given inclusizeStart and exlusiveEnd range",
          () async {
        final mediaPages = await instance.getMediaPagesInRange(
            Duration(seconds: 2), Duration(seconds: 5, milliseconds: 500));

        expect(mediaPages, hasLength(2));

        expect(mediaPages.first.header.mediaPageNumber, 2);
        expect(mediaPages.first.header.pageDurationInMillis,
            Duration(seconds: 3).inMilliseconds);
        expect(mediaPages.first.compressedAudioData,
            Uint8List.fromList([0xbb, 0xcc]));

        expect(mediaPages.last.header.mediaPageNumber, 3);
        expect(mediaPages.last.header.pageDurationInMillis,
            Duration(seconds: 1).inMilliseconds);
        expect(mediaPages.last.compressedAudioData,
            Uint8List.fromList([0xdd, 0xee]));
      });

      test(
          "Should return the MediaPage that overlaps inclusizeStart as the first Media Page in the given range",
          () async {
        final mediaPages = await instance.getMediaPagesInRange(
            Duration(seconds: 1), Duration(seconds: 5));

        expect(mediaPages, hasLength(2));

        expect(mediaPages.first.header.mediaPageNumber, 1);
        expect(mediaPages.first.header.pageDurationInMillis,
            Duration(seconds: 2).inMilliseconds);
      });
      test(
          "Should return the MediaPage that overlaps exlusiveEnd as the last MediaPage in the given range",
          () async {
        final mediaPages = await instance.getMediaPagesInRange(
            Duration(seconds: 0), Duration(seconds: 4));

        expect(mediaPages.length, 2);

        expect(mediaPages.last.header.mediaPageNumber, 2);
        expect(mediaPages.last.header.pageDurationInMillis,
            Duration(seconds: 3).inMilliseconds);
        expect(mediaPages.last.compressedAudioData,
            Uint8List.fromList([0xbb, 0xcc]));
      });
      test("Should replace missing MediaPages with void Media Pages", () async {
        final mediaPages = await instance.getMediaPagesInRange(
            Duration(seconds: 6), Duration(seconds: 6, milliseconds: 500));

        expect(mediaPages, hasLength(1));
        expect(mediaPages.first.isVoid, isTrue);
      });
      test("Should replace corrupted MediaPages with void MediaPages",
          () async {
        final mediaPages = await instance.getMediaPagesInRange(
            Duration(seconds: 14), Duration(seconds: 18));

        expect(mediaPages, hasLength(1));
        expect(mediaPages.first.isVoid, isTrue);
      });
    });
  });
}
