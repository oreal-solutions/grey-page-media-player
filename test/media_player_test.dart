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
    pageDurationInMillis: Duration(seconds: 2).inMilliseconds,
    vectorFrame: RenderingInstructions(viewport: Viewport(width: 200)),
  ),
  Uint8List.fromList([0xaa, 0xbb, 0xcc]),
);

final readableMediaPage1Second = ReadableMediaPage(
  MediaPageHeader(
    mediaPageNumber: 1,
    pageDurationInMillis: Duration(seconds: 1).inMilliseconds,
    vectorFrame: RenderingInstructions(viewport: Viewport(width: 100)),
  ),
  Uint8List.fromList([0xdd, 0xee, 0xff]),
);

final readableMediaPage3Seconds = ReadableMediaPage(
  MediaPageHeader(
    mediaPageNumber: 2,
    pageDurationInMillis: Duration(seconds: 3).inMilliseconds,
    vectorFrame: RenderingInstructions(viewport: Viewport(width: 300)),
  ),
  Uint8List.fromList([0xab, 0xbc, 0xcd]),
);

final readableMediaPage10Seconds = ReadableMediaPage(
  MediaPageHeader(
    mediaPageNumber: 3,
    pageDurationInMillis: Duration(seconds: 10).inMilliseconds,
    vectorFrame: RenderingInstructions(viewport: Viewport(width: 400)),
  ),
  Uint8List.fromList([0xac, 0xcd, 0xef]),
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
        "Should return the same videoDuration as the one returned by the provided VideoReader",
        () async {
      final instance = MediaPlayer.makeInstance();
      await instance.initialiseWith(StubbedVideoReader(
          duration: Duration(minutes: 4), audioProperties: AudioProperties()));

      expect(instance.videoDuration, Duration(minutes: 4));
    });

    group("initialiseWith", () {
      test("Should put the MediaPlayer in a paused state", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));

        expect(instance.state, MediaPlayerState.paused);
      });

      test("Should set the seekPosition to zero", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));

        expect(instance.seekPosition, Duration.zero);
      });

      test("Should notify listeners", () async {
        bool wasListenerCalled = false;

        final instance = MediaPlayer.makeInstance();
        instance.addListener(() => wasListenerCalled = true);

        await await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));

        expect(wasListenerCalled, isTrue);
      });

      test(
          "Should initialise the given VideoReader, Opus16Decoder, and PCM16AudioPlayer",
          () async {
        final instance = MediaPlayer.makeInstance();
        final videoReader = StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        );

        when(audioDecoder.initialise(any)).thenAnswer((_) async {});
        when(audioPlayer.initialise(any)).thenAnswer((_) async {});

        await instance.initialiseWith(
          videoReader,
          opus16decoder: audioDecoder,
          pcm16audioPlayer: audioPlayer,
        );

        expect(videoReader.wasInitialised, isTrue);
        verify(audioDecoder.initialise(AudioProperties())).called(1);
        verify(audioPlayer.initialise(AudioProperties())).called(1);
      });
    });

    group("play()", () {
      test("Should put the MediaPlayer in a playing state", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));
        instance.play();

        expect(instance.state, MediaPlayerState.playing);
      });
      test("Should notify listeners", () async {
        bool wasListenerCalled = false;

        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));

        instance.addListener(() => wasListenerCalled = true);
        instance.play();

        expect(wasListenerCalled, isTrue);
      });
    });

    group("pause()", () {
      test("Should pause the seekPosition counter", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));
        instance.play();

        instance.pause();
        await Future.delayed(Duration(milliseconds: 200));

        expect(instance.seekPosition, lessThan(Duration(milliseconds: 100)));
      });
      test("Should put the MediaPlayer in a paused state", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));
        instance.play();

        instance.pause();

        expect(instance.state, MediaPlayerState.paused);
      });
      test("Should notify listeners", () async {
        bool wasListenerCalled = false;

        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero, audioProperties: AudioProperties()));
        instance.play();

        instance.addListener(() => wasListenerCalled = true);
        instance.pause();
        expect(wasListenerCalled, isTrue);
      });
    });

    group("stop()", () {
      test("Should clear the given PCM16AudioPlayer", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(
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
        await instance.initialiseWith(StubbedVideoReader(
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
        await instance.initialiseWith(StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        ));
        instance.play();
        await Future.delayed(Duration(milliseconds: 100));

        instance.stop();
        await Future.delayed(Duration(milliseconds: 100));
        expect(instance.seekPosition, Duration.zero);
      });
      test("Should put the MediaPlayer in a paused state", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        ));
        instance.play();

        instance.stop();
        expect(instance.state, MediaPlayerState.paused);
      });
      test("Should notify listeners", () async {
        bool wasListenerCalled = false;

        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
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
      test("Should set seekPosition to the new seekPosition", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
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

        when(videoReader.initialise()).thenAnswer((_) async {});
        when(videoReader.getVideoDuration())
            .thenAnswer((_) async => Duration.zero);
        when(videoReader.getAudioProperties())
            .thenAnswer((_) async => AudioProperties());

        await instance.initialiseWith(videoReader);

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
          () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero,
            audioProperties: AudioProperties(),
            mediaPages: [
              readableMediaPage2Seconds,
              readableMediaPage3Seconds,
              readableMediaPage1Second
            ]));

        // Initiate full buffering
        instance.getCurrentVectorFrame();
        await Future.delayed(Duration(milliseconds: 1));

        instance.seek(to: Duration.zero);

        expect(instance.getCurrentVectorFrame(),
            readableMediaPage2Seconds.header.vectorFrame);
      });
      test("Should return the frame at the current seekPosition", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration.zero,
            audioProperties: AudioProperties(),
            mediaPages: [
              readableMediaPage2Seconds,
              readableMediaPage3Seconds,
              readableMediaPage1Second
            ]));

        // Initiate full buffering
        instance.getCurrentVectorFrame();
        await Future.delayed(Duration(milliseconds: 1));

        instance.seek(
            to: Duration(
                seconds: 3, milliseconds: 500)); // 3.5 seconds into the video

        expect(instance.getCurrentVectorFrame(),
            readableMediaPage3Seconds.header.vectorFrame);
      });
      test(
          "Should return last frame in the video when seekPosition equals the duration of the video",
          () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration(seconds: 6),
            audioProperties: AudioProperties(),
            mediaPages: [
              readableMediaPage2Seconds,
              readableMediaPage3Seconds,
              readableMediaPage1Second
            ]));

        // Initiate full buffering
        instance.getCurrentVectorFrame();
        await Future.delayed(Duration(milliseconds: 1));

        instance.seek(to: Duration(seconds: 6));

        expect(instance.getCurrentVectorFrame(),
            readableMediaPage1Second.header.vectorFrame);
      });
      test(
          "Should return the last frame in the video when seekPosition is greater than the duration of the video",
          () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(StubbedVideoReader(
            duration: Duration(seconds: 6),
            audioProperties: AudioProperties(),
            mediaPages: [
              readableMediaPage2Seconds,
              readableMediaPage3Seconds,
              readableMediaPage1Second
            ]));

        // Initiate full buffering
        instance.getCurrentVectorFrame();
        await Future.delayed(Duration(milliseconds: 1));

        instance.seek(to: Duration(seconds: 10));

        expect(instance.getCurrentVectorFrame(),
            readableMediaPage1Second.header.vectorFrame);
      });

      group("When the vector frame at the current seekPosition is void", () {
        test("It should return the last returned non void vector frame",
            () async {
          final instance = MediaPlayer.makeInstance();
          await instance.initialiseWith(StubbedVideoReader(
              duration: Duration.zero,
              audioProperties: AudioProperties(),
              mediaPages: [
                readableMediaPage2Seconds,
                ReadableMediaPage(null, Uint8List(0)), // length is 2s
                ReadableMediaPage(null, Uint8List(0)), // length is 2s
                readableMediaPage3Seconds,
                readableMediaPage1Second
              ]));

          // Initiate full buffering
          instance.getCurrentVectorFrame();
          await Future.delayed(Duration(milliseconds: 1));

          instance.seek(to: Duration(seconds: 5));

          expect(instance.getCurrentVectorFrame(),
              readableMediaPage2Seconds.header.vectorFrame);
        });
        group(
            "When there are no vector frames coming before the requested vector frame",
            () {
          test("It should return the next non void vector frame", () async {
            final instance = MediaPlayer.makeInstance();
            await instance.initialiseWith(StubbedVideoReader(
                duration: Duration.zero,
                audioProperties: AudioProperties(),
                mediaPages: [
                  ReadableMediaPage(null, Uint8List(0)), // length is 2s
                  ReadableMediaPage(null, Uint8List(0)), // length is 2s
                  readableMediaPage3Seconds,
                  readableMediaPage1Second
                ]));

            // Initiate full buffering
            instance.getCurrentVectorFrame();
            await Future.delayed(Duration(milliseconds: 1));

            instance.seek(to: Duration.zero);

            expect(instance.getCurrentVectorFrame(),
                readableMediaPage3Seconds.header.vectorFrame);
          });
        });
      });
    });

    group("getCurrentVectorFrameAndPushAudio()", () {
      test(
          "Returns a void vector frame without pushing audio when the MediaPlayer is in the buffering state",
          () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(
          StubbedVideoReader(
            duration: Duration.zero,
            audioProperties: AudioProperties(),
          ),
          opus16decoder: audioDecoder,
          pcm16audioPlayer: audioPlayer,
        );

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
        expect(instance.getCurrentVectorFrameAndPushAudio().isVoid, isTrue);
        await Future.delayed(Duration(milliseconds: 50));
        expect(instance.getCurrentVectorFrameAndPushAudio().isVoid, isTrue);

        verifyNever(audioPlayer.writeToBuffer(any));
      });
      group(
          "When a specific vector frame is requested for the first time in a row",
          () {
        test(
            "Should return the vector frame of and push the decoded audio of the first MediaPage when seekPosition is at zero",
            () async {
          final instance = MediaPlayer.makeInstance();
          await instance.initialiseWith(
            StubbedVideoReader(
                duration: Duration.zero,
                audioProperties: AudioProperties(),
                mediaPages: [
                  readableMediaPage2Seconds,
                  readableMediaPage3Seconds,
                  readableMediaPage1Second
                ]),
            opus16decoder: audioDecoder,
            pcm16audioPlayer: audioPlayer,
          );

          when(audioDecoder
                  .decode(readableMediaPage2Seconds.compressedAudioData))
              .thenReturn(Uint8List.fromList([0xcc, 0xbb]));

          // Initiate full buffering
          instance.getCurrentVectorFrameAndPushAudio();
          await Future.delayed(Duration(milliseconds: 1));

          instance.seek(to: Duration.zero);

          expect(instance.getCurrentVectorFrameAndPushAudio(),
              readableMediaPage2Seconds.header.vectorFrame);

          verify(audioPlayer.writeToBuffer(Uint8List.fromList([0xcc, 0xbb])))
              .called(1);
        });
        test(
            "Should return the vector frame of and push the decoded audio of the MediaPage at the current seekPosition",
            () async {
          final instance = MediaPlayer.makeInstance();
          await instance.initialiseWith(
            StubbedVideoReader(
                duration: Duration.zero,
                audioProperties: AudioProperties(),
                mediaPages: [
                  readableMediaPage2Seconds,
                  readableMediaPage3Seconds,
                  readableMediaPage1Second
                ]),
            opus16decoder: audioDecoder,
            pcm16audioPlayer: audioPlayer,
          );

          when(audioDecoder
                  .decode(readableMediaPage3Seconds.compressedAudioData))
              .thenReturn(Uint8List.fromList([0xaa, 0xbb]));

          // Initiate full buffering
          instance.getCurrentVectorFrameAndPushAudio();
          await Future.delayed(Duration(milliseconds: 1));

          instance.seek(
              to: Duration(
                  seconds: 3, milliseconds: 500)); // 3.5 seconds into the video

          expect(instance.getCurrentVectorFrameAndPushAudio(),
              readableMediaPage3Seconds.header.vectorFrame);

          verify(audioPlayer.writeToBuffer(Uint8List.fromList([0xaa, 0xbb])))
              .called(1);
        });
        test(
            "Should return the vector frame of and push the decoded audio of the last MediaPage when seekPosition equals the duration of the video",
            () async {
          final instance = MediaPlayer.makeInstance();
          await instance.initialiseWith(
            StubbedVideoReader(
                duration: Duration(seconds: 6),
                audioProperties: AudioProperties(),
                mediaPages: [
                  readableMediaPage2Seconds,
                  readableMediaPage3Seconds,
                  readableMediaPage1Second
                ]),
            opus16decoder: audioDecoder,
            pcm16audioPlayer: audioPlayer,
          );

          when(audioDecoder
                  .decode(readableMediaPage1Second.compressedAudioData))
              .thenReturn(Uint8List.fromList([0xaa, 0xdd]));

          // Initiate full buffering
          instance.getCurrentVectorFrameAndPushAudio();
          await Future.delayed(Duration(milliseconds: 1));

          instance.seek(to: Duration(seconds: 6));

          expect(instance.getCurrentVectorFrameAndPushAudio(),
              readableMediaPage1Second.header.vectorFrame);

          verify(audioPlayer.writeToBuffer(Uint8List.fromList([0xaa, 0xdd])))
              .called(1);
        });
        test(
            "Should return the vector frame of and push the decoded audio of the last MediaPage when seekPosition is greater than the duration of the video",
            () async {
          final instance = MediaPlayer.makeInstance();
          await instance.initialiseWith(
            StubbedVideoReader(
                duration: Duration(seconds: 6),
                audioProperties: AudioProperties(),
                mediaPages: [
                  readableMediaPage2Seconds,
                  readableMediaPage3Seconds,
                  readableMediaPage1Second
                ]),
            opus16decoder: audioDecoder,
            pcm16audioPlayer: audioPlayer,
          );

          when(audioDecoder
                  .decode(readableMediaPage1Second.compressedAudioData))
              .thenReturn(Uint8List.fromList([0xaa, 0xdd]));

          // Initiate full buffering
          instance.getCurrentVectorFrameAndPushAudio();
          await Future.delayed(Duration(milliseconds: 1));

          instance.seek(to: Duration(seconds: 10));

          expect(instance.getCurrentVectorFrameAndPushAudio(),
              readableMediaPage1Second.header.vectorFrame);

          verify(audioPlayer.writeToBuffer(Uint8List.fromList([0xaa, 0xdd])))
              .called(1);
        });

        group("When the vector frame comes from a MediaPage with no audio", () {
          test("Should not call the given Opus16Decoder", () async {
            final instance = MediaPlayer.makeInstance();
            await instance.initialiseWith(
              StubbedVideoReader(
                  duration: Duration.zero,
                  audioProperties: AudioProperties(),
                  mediaPages: [
                    ReadableMediaPage(
                        readableMediaPage2Seconds.header, Uint8List(0)),
                  ]),
              opus16decoder: audioDecoder,
              pcm16audioPlayer: audioPlayer,
            );

            // Initiate full buffering.
            instance.getCurrentVectorFrameAndPushAudio();
            await Future.delayed(Duration(milliseconds: 1));
            reset(audioDecoder);

            instance.seek(to: Duration.zero);

            instance.getCurrentVectorFrameAndPushAudio();

            verifyNever(audioDecoder.decode(any));
          });
        });
      });

      group(
          "When a specific vector frame is requested for more than the first time in a row",
          () {
        test(
            "Should return the vector frame without pushing its audio in in the successive times",
            () async {
          final instance = MediaPlayer.makeInstance();
          await instance.initialiseWith(
            StubbedVideoReader(
                duration: Duration.zero,
                audioProperties: AudioProperties(),
                mediaPages: [
                  readableMediaPage2Seconds,
                ]),
            opus16decoder: audioDecoder,
            pcm16audioPlayer: audioPlayer,
          );

          when(audioDecoder.decode(any))
              .thenReturn(Uint8List.fromList([0xaa, 0xdd]));

          // Initiate full buffering
          instance.getCurrentVectorFrameAndPushAudio();
          await Future.delayed(Duration(milliseconds: 1));

          instance.seek(to: Duration.zero);
          instance.getCurrentVectorFrameAndPushAudio();
          instance.seek(to: Duration(seconds: 1));
          instance.getCurrentVectorFrameAndPushAudio();

          verify(audioPlayer.writeToBuffer(any)).called(1);
        });
      });

      group(
          "When the Media Page of the vector frame at the current seekPosition is void",
          () {
        test(
            "It should return the vector frame of the last non void Media Page and push the recreated decoded audio",
            () async {
          final instance = MediaPlayer.makeInstance();
          await instance.initialiseWith(
            StubbedVideoReader(
                duration: Duration.zero,
                audioProperties: AudioProperties(),
                mediaPages: [
                  readableMediaPage2Seconds,
                  ReadableMediaPage(null, Uint8List(0)), // length is 2s
                  ReadableMediaPage(null, Uint8List(0)), // length is 2s
                  readableMediaPage3Seconds,
                  readableMediaPage1Second
                ]),
            opus16decoder: audioDecoder,
            pcm16audioPlayer: audioPlayer,
          );

          when(audioDecoder.decode(Uint8List(0)))
              .thenReturn(Uint8List.fromList([0xaa, 0xdd]));

          // Initiate full buffering
          instance.getCurrentVectorFrameAndPushAudio();
          await Future.delayed(Duration(milliseconds: 1));

          instance.seek(to: Duration(seconds: 5));

          expect(instance.getCurrentVectorFrameAndPushAudio(),
              readableMediaPage2Seconds.header.vectorFrame);

          verify(audioPlayer.writeToBuffer(Uint8List.fromList([0xaa, 0xdd])))
              .called(1);
        });

        group(
            "When there are no Media Pages coming before the requested vector frames' Media Page",
            () {
          test(
              "It should return the vector frame of and push the decoded audio of the next Media Page",
              () async {
            final instance = MediaPlayer.makeInstance();
            await instance.initialiseWith(
              StubbedVideoReader(
                  duration: Duration.zero,
                  audioProperties: AudioProperties(),
                  mediaPages: [
                    ReadableMediaPage(null, Uint8List(0)), // length is 2s
                    ReadableMediaPage(null, Uint8List(0)), // length is 2s
                    readableMediaPage3Seconds,
                    readableMediaPage1Second
                  ]),
              opus16decoder: audioDecoder,
              pcm16audioPlayer: audioPlayer,
            );

            when(audioDecoder
                    .decode(readableMediaPage3Seconds.compressedAudioData))
                .thenReturn(Uint8List.fromList([0xaa, 0xdd]));

            // Initiate full buffering
            instance.getCurrentVectorFrameAndPushAudio();
            await Future.delayed(Duration(milliseconds: 1));

            instance.seek(to: Duration.zero);

            expect(instance.getCurrentVectorFrameAndPushAudio(),
                readableMediaPage3Seconds.header.vectorFrame);

            verify(audioPlayer.writeToBuffer(Uint8List.fromList([0xaa, 0xdd])))
                .called(1);
          });
        });
      });
    });

    group("release()", () {
      test(
          "Should release the given VideoReader, Opus16Decoder, and PCM16AudioPlayer",
          () async {
        final instance = MediaPlayer.makeInstance();
        final videoReader = StubbedVideoReader(
          duration: Duration.zero,
          audioProperties: AudioProperties(),
        );
        await instance.initialiseWith(
          videoReader,
          opus16decoder: audioDecoder,
          pcm16audioPlayer: audioPlayer,
        );

        instance.release();

        expect(videoReader.wasReleased, isTrue);
        verify(audioDecoder.release()).called(1);
        verify(audioPlayer.release()).called(1);
      });
      test("Should the MediPlayer in a defunct state", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(
          StubbedVideoReader(
            duration: Duration.zero,
            audioProperties: AudioProperties(),
          ),
        );

        instance.release();

        expect(instance.state, MediaPlayerState.defunct);
      });
      test("Should set lastError to Void", () async {
        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(
          StubbedVideoReader(
            duration: Duration.zero,
            audioProperties: AudioProperties(),
          ),
        );

        instance.release();

        expect(instance.lastError.isVoid, isTrue);
      });
      test("Should notify listeners", () async {
        bool didNotifyListener = false;

        final instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(
          StubbedVideoReader(
            duration: Duration.zero,
            audioProperties: AudioProperties(),
          ),
        );

        instance.addListener(() => didNotifyListener = true);
        instance.release();

        expect(didNotifyListener, isTrue);
      });
    });

    group("When during soft buffering the provided VideoReader throws an error",
        () {
      MediaPlayer instance;
      bool wasListenerNotified = false;
      setUp(() async {
        when(videoReader.initialise()).thenAnswer((_) async {});
        when(videoReader.getVideoDuration())
            .thenAnswer((_) async => Duration.zero);
        when(videoReader.getAudioProperties())
            .thenAnswer((_) async => AudioProperties());

        instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(videoReader);
        instance.setForwardBufferSize(Duration(seconds: 10));

        // Initiate full buffering
        when(videoReader.getMediaPagesInRange(any, any))
            .thenAnswer((_) async => [readableMediaPage10Seconds]);
        instance.getCurrentVectorFrame();
        await Future.delayed(Duration(milliseconds: 1));

        // Seek the forward buffer to less than 70% of its capacity then request a
        // frame to initiate soft buffering and then throw when it happens.
        instance.addListener(() => wasListenerNotified = true);
        when(videoReader.getMediaPagesInRange(any, any)).thenThrow('abc');
        instance.seek(to: Duration(seconds: 4));
        instance.getCurrentVectorFrame();

        // Wait for the soft buffer coroutine to finish.
        await Future.delayed(Duration(milliseconds: 1));
      });

      tearDown(() {
        instance = null;
        wasListenerNotified = false;
      });

      test("Should turn off soft buffering", () {
        expect(instance.isSoftBufferingEnabled, isFalse);
      });
      test("Should set lastError to the error thrown by the VideoReader", () {
        expect(instance.lastError, 'abc');
      });
      test("Should notify listeners", () {
        expect(wasListenerNotified, isTrue);
      });
      group("And then trySoftBufferingAgain() is called", () {
        test("It should enable its soft buffering couroutine again", () async {
          int numberOfTimesSoftBufferingWasTriedAgain = 0;

          when(videoReader.getMediaPagesInRange(any, any))
              .thenAnswer((_) async {
            numberOfTimesSoftBufferingWasTriedAgain++;
            return [];
          });

          instance.trySoftBufferingAgain(); // Will schedule first call here
          await Future.delayed(Duration(milliseconds: 1));
          instance.getCurrentVectorFrame(); // Will schedule second call here
          await Future.delayed(Duration(milliseconds: 1));

          expect(numberOfTimesSoftBufferingWasTriedAgain, 2);
          expect(instance.isSoftBufferingEnabled, isTrue);
        });
      });
    });

    group("When during full buffering the provided VideoReader throws an error",
        () {
      MediaPlayer instance;
      bool wasListenerNotified = false;
      setUp(() async {
        when(videoReader.initialise()).thenAnswer((_) async {});
        when(videoReader.getVideoDuration())
            .thenAnswer((_) async => Duration.zero);
        when(videoReader.getAudioProperties())
            .thenAnswer((_) async => AudioProperties());

        instance = MediaPlayer.makeInstance();
        await instance.initialiseWith(
          videoReader,
          opus16decoder: audioDecoder,
          pcm16audioPlayer: audioPlayer,
        );
        instance.setForwardBufferSize(Duration(seconds: 10));

        // Initiate full buffering and throw when it happens.
        instance.addListener(() => wasListenerNotified = true);
        when(videoReader.getMediaPagesInRange(any, any)).thenThrow('bcd');
        instance.getCurrentVectorFrame();

        // Wait for the full buffering coroutine to finish.
        await Future.delayed(Duration(milliseconds: 1));
      });

      tearDown(() {
        instance = null;
        wasListenerNotified = false;
      });

      test("Should put the MediaPlayer in a defunct state", () {
        expect(instance.state, MediaPlayerState.defunct);
      });
      test("Should release the given Opus16Decoder", () {
        verify(audioDecoder.release()).called(1);
      });
      test("Should release the given PCM16AudioPlayer", () {
        verify(audioPlayer.release()).called(1);
      });
      test("Should set lastError to the error thrown by the VideoReader", () {
        expect(instance.lastError, 'bcd');
      });
      test("Should notify listeners", () {
        expect(wasListenerNotified, isTrue);
      });
    });

    test(
        "During full buffering the MediaPlayer should be in the buffering state",
        () async {
      MediaPlayerState stateDuringFullBuffering;

      when(videoReader.initialise()).thenAnswer((_) async {});
      when(videoReader.getVideoDuration())
          .thenAnswer((_) async => Duration.zero);
      when(videoReader.getAudioProperties())
          .thenAnswer((_) async => AudioProperties());

      final instance = MediaPlayer.makeInstance();
      await instance.initialiseWith(videoReader);

      when(videoReader.getMediaPagesInRange(any, any)).thenAnswer((_) async {
        stateDuringFullBuffering = instance.state;
        return [];
      });

      // Initiate full buffering
      instance.getCurrentVectorFrame();
      await Future.delayed(Duration(milliseconds: 1));

      expect(stateDuringFullBuffering, MediaPlayerState.buffering);
    });
    test(
        "After full buffering the Opus16Decoder should be called with empty data but the PCM16AudioPlayer should never called with the results",
        () async {
      when(videoReader.initialise()).thenAnswer((_) async {});
      when(videoReader.getVideoDuration())
          .thenAnswer((_) async => Duration.zero);
      when(videoReader.getAudioProperties())
          .thenAnswer((_) async => AudioProperties());

      when(videoReader.getMediaPagesInRange(any, any))
          .thenAnswer((_) async => [readableMediaPage10Seconds]);

      final instance = MediaPlayer.makeInstance();
      await instance.initialiseWith(
        videoReader,
        opus16decoder: audioDecoder,
        pcm16audioPlayer: audioPlayer,
      );

      // Initiate full buffering
      instance.getCurrentVectorFrame();
      await Future.delayed(Duration(milliseconds: 1));

      verify(audioDecoder.decode(Uint8List(0))).called(1);
      verifyNever(audioPlayer.writeToBuffer(any));
    });
  });
}
