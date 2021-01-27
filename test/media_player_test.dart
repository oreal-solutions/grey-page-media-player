import 'dart:typed_data';

import 'package:grey_page_media_player/src/audio/opus16_decoder.dart';
import 'package:grey_page_media_player/src/audio/pcm16_audio_player.dart';
import 'package:grey_page_media_player/src/media_player.dart';
import 'package:grey_page_media_player/src/readers/video_reader.dart';
import 'package:mockito/mockito.dart';
import 'package:npxl_video/generated/npxl_video.pb.dart';
import 'package:npxl_video/npxl_video.dart';
import 'package:test/test.dart';

import 'package:grey_page_media_player/src/void_extensions.dart';

class StubbedVideoReader implements VideoReader {
  final Duration duration;
  final AudioProperties audioProperties;
  final List<ReadableMediaPage> mediaPages;

  bool wasInitialised = false;
  bool wasReleased = false;

  StubbedVideoReader(
      {this.duration, this.audioProperties, this.mediaPages = const []});

  Future<Duration> getVideoDuration() async => duration;

  Future<List<ReadableMediaPage>> getMediaPagesInRange(
          Duration start, Duration end) async =>
      mediaPages;

  Future<AudioProperties> getAudioProperties() async => audioProperties;

  Future<void> initialise() async {
    wasInitialised = true;
  }

  Future<void> release() async {
    wasReleased = true;
  }
}

class MockVideoReader extends Mock implements VideoReader {}

class MockPCM16AudioPlayer extends Mock implements PCM16AudioPlayer {}

class MockOpus16Decoder extends Mock implements Opus16Decoder {}

final readableMediaPage2Seconds = ReadableMediaPage(
  MediaPageHeader(
    mediaPageNumber: 0,
    pageDurationInMillis: Duration(seconds: 2).inMicroseconds,
    vectorFrame: RenderingInstructions(viewport: Viewport(width: 200)),
  ),
  Uint8List.fromList([0xaa, 0xbb, 0xcc]),
);

final readableMediaPage1Second = ReadableMediaPage(
  MediaPageHeader(
    mediaPageNumber: 1,
    pageDurationInMillis: Duration(seconds: 1).inMicroseconds,
    vectorFrame: RenderingInstructions(viewport: Viewport(width: 100)),
  ),
  Uint8List.fromList([0xdd, 0xee, 0xff]),
);

final readableMediaPage3Seconds = ReadableMediaPage(
  MediaPageHeader(
    mediaPageNumber: 2,
    pageDurationInMillis: Duration(seconds: 3).inMicroseconds,
    vectorFrame: RenderingInstructions(viewport: Viewport(width: 300)),
  ),
  Uint8List.fromList([0xab, 0xbc, 0xcd]),
);

void main() {
  VideoReader videoReader;
  Opus16Decoder audioDecoder;
  PCM16AudioPlayer audioPlayer;

  setUp(() {
    videoReader = MockVideoReader();
    audioDecoder = MockOpus16Decoder();
    audioPlayer = MockPCM16AudioPlayer();
  });

  tearDown(() {
    videoReader = null;
    audioDecoder = null;
    audioPlayer = null;
  });

  group("MediaPlayer Tests", () {
    test(
        "Should return the smae videoDuration as the one returned by the provided VideoReader",
        () {
      final instance = MediaPlayer.makeInstance();
      instance.initialiseWith(StubbedVideoReader(
          duration: Duration(minutes: 4), audioProperties: AudioProperties()));

      expect(instance.videoDuration, Duration(minutes: 4));
    });

    group("initialiseWith", () {
      test("Should put the MediaPlayer in a paused state", () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));

        expect(instance.state, MediaPlayerState.paused);
      });

      test("Should set the seekPosition to zero", () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));

        expect(instance.seekPosition, Duration.zero);
      });

      test("Should notify listeners", () {
        bool wasListenerCalled = false;

        final instance = MediaPlayer.makeInstance();
        instance.addListener(() => wasListenerCalled = true);

        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));

        expect(wasListenerCalled, isTrue);
      });

      test(
          "Should initialise the given VideoReader, Opus16Decoder, and PCM16AudioPlayer",
          () {
        final instance = MediaPlayer.makeInstance();
        final videoReader = StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        );
        instance.initialiseWith(
          videoReader,
          opus16decoder: audioDecoder,
          pcm16audioPlayer: audioPlayer,
        );

        expect(videoReader.wasInitialised, isTrue);
        verify(audioDecoder.initialise(any)).called(1);
        verify(audioPlayer.initialise(any)).called(1);
      });
    });

    group("play()", () {
      test("Should put the MediaPlayer in a playing state", () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));
        instance.play();

        expect(instance.state, MediaPlayerState.playing);
      });
      test("Should notify listeners", () {
        bool wasListenerCalled = false;

        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));

        instance.addListener(() => wasListenerCalled = true);
        instance.play();

        expect(wasListenerCalled, isTrue);
      });
    });

    group("pause()", () {
      test("Should pause the seekPosition counter", () async {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));
        instance.play();

        instance.pause();
        await Future.delayed(Duration(milliseconds: 200));

        expect(instance.seekPosition, lessThan(Duration(milliseconds: 100)));
      });
      test("Should put the MediaPlayer in a paused state", () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));
        instance.play();

        instance.pause();

        expect(instance.state, MediaPlayerState.paused);
      });
      test("Should notify listeners", () {
        bool wasListenerCalled = false;

        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));
        instance.play();

        instance.addListener(() => wasListenerCalled = true);
        instance.pause();
        expect(wasListenerCalled, isTrue);
      });
    });

    group("stop()", () {
      test("Should clear the given PCM16AudioPlayer", () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(
          StubbedVideoReader(
            duration: Duration.zero,
            audioProperties: AudioProperties(),
          ),
          opus16decoder: audioDecoder,
          pcm16audioPlayer: audioPlayer,
        );
        instance.play();

        instance.stop();

        verify(audioPlayer.clearBuffer()).called(1);
      });
      test("Should set the seekPosition to zero", () async {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        ));
        instance.play();
        await Future.delayed(Duration(milliseconds: 100));

        instance.stop();
        expect(instance.seekPosition, Duration.zero);
      });
      test("Should pause the seekPosition counter", () async {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        ));
        instance.play();
        await Future.delayed(Duration(milliseconds: 100));

        instance.stop();
        await Future.delayed(Duration(milliseconds: 100));
        expect(instance.seekPosition, Duration.zero);
      });
      test("Should put the MediaPlayer in a paused state", () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        ));
        instance.play();

        instance.stop();
        expect(instance.state, MediaPlayerState.paused);
      });
      test("Should notify listeners", () {
        bool wasListenerCalled = false;

        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        ));
        instance.play();

        instance.addListener(() => wasListenerCalled = true);
        instance.stop();

        expect(wasListenerCalled, isTrue);
      });
    });

    group("seek(Duration to)", () {
      test("Should set seekPosition to the new seekPosition", () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        ));

        instance.seek(to: Duration(seconds: 5));
        expect(instance.seekPosition, Duration(seconds: 5));
      });
    });

    group("getCurrentVectorFrame()", () {
      test(
          "Returns a void vector frame when the MediaPlayer is in the buffering state",
          () async {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        ));

        when(videoReader.initialise()).thenAnswer((_) async {});
        when(videoReader.getVideoDuration())
            .thenAnswer((_) async => Duration.zero);
        when(videoReader.getAudioProperties())
            .thenAnswer((_) async => AudioProperties());

        // Will cause a delay in the buffering.
        when(videoReader.getMediaPagesInRange(any, any)).thenAnswer(
            (_) => Future.delayed(Duration(milliseconds: 100), () async => []));

        // First call will put the MediaPlayer in a full buffering state.
        // Second call will be received by the MediaPlayer while it's busy full buffering
        expect(instance.getCurrentVectorFrame().isVoid, isTrue);
        await Future.delayed(Duration(milliseconds: 50));
        expect(instance.getCurrentVectorFrame().isVoid, isTrue);
      });

      test(
          "Should return the very first frame in the video when seekPosition is at zero",
          () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero,
            audioProperties: AudioProperties(),
            mediaPages: [
              readableMediaPage2Seconds,
              readableMediaPage3Seconds,
              readableMediaPage1Second
            ]));

        instance.seek(to: Duration.zero);

        expect(instance.getCurrentVectorFrame(),
            readableMediaPage2Seconds.header.vectorFrame);
      });
      test("Should return the frame at the current seekPosition", () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero,
            audioProperties: AudioProperties(),
            mediaPages: [
              readableMediaPage2Seconds,
              readableMediaPage3Seconds,
              readableMediaPage1Second
            ]));

        instance.seek(
            to: Duration(
                seconds: 3, milliseconds: 500)); // 3.5 seconds into the video

        expect(instance.getCurrentVectorFrame(),
            readableMediaPage3Seconds.header.vectorFrame);
      });
      test(
          "Should return last frame in the video when seekPosition equals the duration of the video",
          () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration(seconds: 6),
            audioProperties: AudioProperties(),
            mediaPages: [
              readableMediaPage2Seconds,
              readableMediaPage3Seconds,
              readableMediaPage1Second
            ]));

        instance.seek(to: Duration(seconds: 6));

        expect(instance.getCurrentVectorFrame(),
            readableMediaPage1Second.header.vectorFrame);
      });
      test(
          "Should return the last frame in the video when seekPosition is greater than the duration of the video",
          () {
        final instance = MediaPlayer.makeInstance();
        instance.initialiseWith(StubbedVideoReader(
            duration: Duration(seconds: 6),
            audioProperties: AudioProperties(),
            mediaPages: [
              readableMediaPage2Seconds,
              readableMediaPage3Seconds,
              readableMediaPage1Second
            ]));

        instance.seek(to: Duration(seconds: 10));

        expect(instance.getCurrentVectorFrame(),
            readableMediaPage1Second.header.vectorFrame);
      });

      group("When the vector frame at the current seekPosition is void", () {
        test("It should return the last returned non void vector frame", () {
          final instance = MediaPlayer.makeInstance();
          instance.initialiseWith(StubbedVideoReader(
              duration: Duration.zero,
              audioProperties: AudioProperties(),
              mediaPages: [
                readableMediaPage2Seconds,
                ReadableMediaPage(null, Uint8List(0)), // lenght is 2s
                ReadableMediaPage(null, Uint8List(0)), // lenght is 2s
                readableMediaPage3Seconds,
                readableMediaPage1Second
              ]));

          instance.seek(to: Duration(seconds: 5));

          expect(instance.getCurrentVectorFrame(),
              readableMediaPage2Seconds.header.vectorFrame);
        });
        group(
            "When there are no vector frames coming before the requested vector frame",
            () {
          test("It should return the next non void vector frame", () {
            final instance = MediaPlayer.makeInstance();
            instance.initialiseWith(StubbedVideoReader(
                duration: Duration.zero,
                audioProperties: AudioProperties(),
                mediaPages: [
                  readableMediaPage2Seconds,
                  ReadableMediaPage(null, Uint8List(0)), // length is 2s
                  ReadableMediaPage(null, Uint8List(0)), // length is 2s
                  readableMediaPage3Seconds,
                  readableMediaPage1Second
                ]));

            instance.seek(to: Duration(seconds: 2, milliseconds: 2));

            expect(instance.getCurrentVectorFrame(),
                readableMediaPage3Seconds.header.vectorFrame);
          });
        });
      });
    });

    group("getCurrentVectorFrameAndPushAudio()", () {
      test(
          "Returns a void frame without pushing audio when the MediaPlayer is a in the buffering state",
          () {});
      group(
          "When a specific vector frame is requested for the first time in a row",
          () {
        test(
            "Should return the vector frame of and push the decoded audio of the first MediaPage when seekPosition is at zero",
            () {});
        test(
            "Should return the vector frame of and push the decoded audio of the MediaPage at the current seekPosition",
            () {});
        test(
            "Should return the vector frame of and push the decoded audio of the last MediaPage when seekPosition equals the duration of the video",
            () {});
        test(
            "Should return the vector frame of and push the decoded audio of the last MediaPage when seekPosition is greater than the duration of the video",
            () {});

        group("When the vector frame comes from a MediaPage with no audio", () {
          test("Should not call the given Opus16Decoder", () {});
        });
      });

      group(
          "When a specific vector frame is requested for more than the first time in a row",
          () {
        test("Should return the vector frame without pushing its audio", () {});
      });

      group(
          "When the Media Page of the vector frame at the current seekPosition is void",
          () {
        test(
            "It should return the vector frame that comes immediately before the requested frame",
            () {});

        test(
            "It should push the decoded audio of the media page that comes immediately before the requested frame",
            () {});
        group(
            "When there are no Media Pages coming before the requested vector frames' Media Page",
            () {
          test(
              "It should return the vector frame of and push the decoded audio of the next Media Page",
              () {});
        });
      });
    });

    group("release()", () {
      test(
          "Should release the given VideoReader, Opus16Decoder, and PCM16AudioPlayer",
          () {});
      test("Should the MediPlayer in a defunct state", () {});
      test("Should set lastError to Void", () {});
      test("Should listeners", () {});
    });

    group("When during soft buffering the provided VideoReader throws an error",
        () {
      test("Should put the MediaPlayer in a playingWithNoSoftBuffering state",
          () {});
      test(
          "Should set lastError to the error thrown by the VideoReader", () {});
      test("Should notify listeners", () {});
      group(
          "When the MediaPlayer is playingWithNoSoftBuffering and trySoftBufferingAgain is called",
          () {
        test("It should enable its soft buffering couroutine again", () {});
      });
    });

    group("When during full buffering the provided VideoReader throws an error",
        () {
      test("Should put the MediaPlayer in a defunct state", () {});
      test("Should release the given Opus16Decoder", () {});
      test("Should release the given PCM16AudioPlayer", () {});
      test(
          "Should set lastError to the error thrown by the VideoReader", () {});
      test("Should notify listeners", () {});
    });

    test(
        "During full buffering the MediaPlayer should be in na buffering state",
        () {});
    test(
        "After full buffering the Opus16Decoder is called with empty data but the PCM16AudioPlayer is never called with the results",
        () {});
  });
}
