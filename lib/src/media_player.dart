import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:grey_page_media_player/src/audio/opus16_decoder.dart';
import 'package:grey_page_media_player/src/audio/pcm16_audio_player.dart';
import 'package:grey_page_media_player/src/readers/timed_media_queue.dart';
import 'package:grey_page_media_player/src/readers/video_reader.dart';
import 'package:grey_page_media_player/src/void_extensions.dart';
import 'package:npxl_video/generated/npxl_video.pb.dart';
import 'package:npxl_video/npxl_video.dart';

/// A video playback coordinater from a [VideoReader].
///
/// The [MediaPlayer] keeps track of and advances the [seekPosition] as the
/// video is being played. Renders can request the frame to be rendered
/// for the current seek position with [getCurrentVectorFrame] or
/// [getCurrentVectorFrameAndPushAudio].
///
/// The [MediaPlayer] uses the requesting of vector frames as events to
/// update [seekPosition] and push audio (if requested). Therefore, if the
/// video has audio, the client should request frames, frequently enough
/// to ensure the passed [PCM16AudioPlayer] always has audio. It is best
/// to request vector frames at the devices display refresh rate.
///
/// Void [ReadableMediaPage]s from the given [VideoReader] will be
/// recreated with Media Page concealment. This is done by calling
/// the given [Opus16Decoder] with no data and then combining the returned
/// pcm audio data with the vector frame of the previous [ReadableMediaPage]
/// to create a new Media Page. If there happens to be no previous
/// Media Page to copy a vector frame from or the given [Opus16Decoder]
/// cannot reproduce the audio data no Media Page concealment will be done,
/// and the [ReadableMediaPage] will just be discarded.
///
/// Seeking the MediaPlayer can be categorised into two groups, a hard seek
/// and a soft seek. A hard seek is any seek that moves [seekPosition] to a
/// position the [MediaPlayer] does not have buffered Media Pages for. The
/// [MediaPlayer] resolves hard seeks by running the full buffer coroutine
/// which places the Media Player in a [MediaPlayerState.buffering] state,
/// pauses the [seekPosition] counter and then fetches the data to fill the
/// forward buffer to its maximum size. The maximum size of the forward buffer
/// can be set with [setForwardBufferSize]. Any calls to [getCurrentVectorFrame]
/// or [getCurrentVectorFrameAndPushAudio] in the buffering state will return a
/// `void` vector frame and no audio will be pushed. Before playing the newly
/// fetched media pages after a hard seek, the [MediaPlayer] will call the
/// given [Opus16Decoder] with a empty data and discard the results.
/// This is done with the assumption that it it will prepare the decoder to
/// start decoding audio from the current [seekPosition] without having to
/// worry about the skipped frames.
///
/// A soft seek is any seek that is not a hard seek. That is any
/// seek that sets [seekPosition] to a position the [MediaPlayer] does have
/// buffered Media Pages for. Soft seeks trigger soft buffering when the data
/// in the forward buffer is filled with less than 70% of its maximum size.
/// Soft buffering is the same as the last part of full buffering which is
/// basically filling the forward buffer with more media pages to its maximum
/// size.
///
/// The forward buffer is the buffer holding Media Pages from the current
/// [seekPosition] onwards in the increasing side of [seekPosition]. It's size
/// is the total combined duration of the Media Pages it is holding. The backward
/// buffer is the same, but it holds already played media pages. The last Media
/// Page in the backward buffer is the most recently played Media Page. The
/// maximum size of the backward buffer is 70% of whatever the maximum size of the
/// forward buffer is.
///
/// Soft and full buffering are asynchronous operations done with Futures. When
/// an error is thrown during a buffering operation, [lastError] will be set to
/// to the thrown error. If this happens during soft buffering, the [MediaPlayer]
/// will continue playing but soft buffering will be turned off.
/// until it runs out of Media Pages in which case it will attempt full buffering.
/// When an error is thrown during full buffering, the [MediaPlayer] will go into
/// a [MediaPlayerState.defunct] state, in which case it should no longer be used.
///
/// Prior to going into a defunct state, the [MediaPlayer] will attempt to release
/// the given [VideoReader], [Opus16Decoder], and [PCM16AudioPlayer]. Any errors
/// thrown during this clean up process will be silenced and not captured in
/// [lastError].
///
/// When the [MediaPlayer] finishes playing the video, it will pause itself.
/// Call [replay] to play the video all over again from the beginning.
abstract class MediaPlayer extends ChangeNotifier {
  /// The duration of the video.
  ///
  /// This is the value returned by the given [VideoReader].
  Duration get videoDuration;

  /// The current seek position.
  Duration get seekPosition;

  /// The current state of the media player.
  ///
  /// Listeners are notified when this value changes.
  MediaPlayerState get state;

  bool get isSoftBufferingEnabled;

  dynamic get lastError;

  /// Initialises the video [MediaPlayer].
  ///
  /// Listeners will be notified after successful initialissation.
  Future<void> initialiseWith(VideoReader videoReader,
      {Opus16Decoder opus16decoder, PCM16AudioPlayer pcm16audioPlayer});

  /// Resume or begin playback.
  ///
  /// This resumes the [seekPosition] counter.
  void play();

  /// Pause playback.
  ///
  /// This pauses the [seekPosition] counter.
  void pause();

  /// Stop playback.
  ///
  /// Resets the [seekPosition] back to zero, discards the buffered Media Pages,
  /// and clears the given [PCM16AudioPlayer] buffer.
  ///
  /// After calling this method, the MediaPlayer will be in a paused state.
  void stop();

  /// Replay the video.
  ///
  /// Replaying is done by setting [seekPosition] to zero.
  void replay();

  /// Sets [seekPosition] to the given position, [to].
  ///
  /// If [to] is equal to or greater than the [videoDuration], the [MediaPlayer] will
  /// assume it is finished playing the video and, therefore, pause itself.
  void seek({@required Duration to});

  /// Returns the vector frame for the current [seekPosition].
  ///
  /// Use this to mimic audio muting. See: [getCurrentVectorFrameAndPushAudio]
  RenderingInstructions getCurrentVectorFrame();

  /// Returns the vector frame for the current [seekPosition] and writes its audio frame
  /// to the [PCM16AudioPlayer].
  ///
  /// If it happens that the vector frame is returned for more than the first time
  /// in a row, the audio frame will not be written to the [PCM16AudioPlayer] for the
  /// successive times, i.e the audio frame is written only once in the duration the
  /// vector frame is displayed on screen.
  RenderingInstructions getCurrentVectorFrameAndPushAudio();

  /// Sets the size of the forward buffer.
  void setForwardBufferSize(Duration forwardBufferSize);

  /// Tells the [MediaPlayer] to attempt soft buffering again.
  ///
  /// This should be done when [isSoftBufferingEnabled] is false.
  void trySoftBufferingAgain();

  /// Release the given [VideoReader], [Opus16Decoder], and [PCM16AudioPlayer].
  ///
  /// After calling this method the [MediaPlayer] will be in a [MediaPlayerState.defunct]
  /// state.
  void release();

  /// Builds and returns an uninitialised [MediaPlayer] instance.
  static MediaPlayer makeInstance() {
    return _MediaPlayer();
  }
}

enum MediaPlayerState {
  /// The [MediaPlayer] is playing the video.
  playing,

  /// The [MediaPlayer] is currently paused.
  ///
  /// This is when a client has explicitly paused the [MediaPlayer]
  /// or the [MediaPlayer] has finished playing the video.
  paused,

  /// The [MediaPlayer] is in a defunct state and should no longer
  /// be used.
  ///
  /// This is when:
  ///   1. The `release` method has been called on the [MediaPlayer]
  ///   2. The provided [Opus16Decoder] threw a [DefuctOpusDecoderError]
  ///   3. The provided [VideoReader] threw an error/exception during
  ///      full buffering, i.e after a hard seek.
  defunct,

  /// The [MediaPlayer] is doing a full buffering of media pages.
  ///
  /// This is when the [MediaPlayer] has just gone a hard seek.
  buffering,
}

class _MediaPlayer extends MediaPlayer {
  Stopwatch seekPositionCounter = Stopwatch();
  _MediaPageBuffersController buffersController = _MediaPageBuffersController();
  ReadableMediaPage lastQueuedNonVoidMediaPage =
      ReadableMediaPage(null, Uint8List(0));

  _MediaPageReadyToPlay mediaPageWhoseAudioWasLastPushed =
      _MediaPageReadyToPlay.voidInstance();

  dynamic lastError = Void();
  MediaPlayerState state = MediaPlayerState.paused;

  VideoReader videoReader;
  Opus16Decoder audioDecoder;
  PCM16AudioPlayer audioPlayer;

  Duration videoDuration;

  bool isSoftBufferingEnabled = true;

  @override
  Future<void> initialiseWith(VideoReader videoReader,
      {Opus16Decoder opus16decoder, PCM16AudioPlayer pcm16audioPlayer}) async {
    this.videoReader = videoReader;
    this.audioDecoder = opus16decoder;
    this.audioPlayer = pcm16audioPlayer;

    await videoReader.initialise();
    final audioProperties = await videoReader.getAudioProperties();
    videoDuration = await videoReader.getVideoDuration();

    if (audioDecoder != null) await audioDecoder.initialise(audioProperties);
    if (audioPlayer != null) await audioPlayer.initialise(audioProperties);

    notifyListeners();
  }

  @override
  void pause() {
    seekPositionCounter.stop();
    state = MediaPlayerState.paused;
    notifyListeners();
  }

  @override
  void play() {
    seekPositionCounter.start();
    state = MediaPlayerState.playing;
    notifyListeners();
  }

  @override
  void stop() {
    state = MediaPlayerState.paused;
    seekPositionCounter.stop();
    seekPositionCounter.reset();

    audioPlayer?.clearBuffer();
    notifyListeners();
  }

  @override
  void release() {
    videoReader.release();
    audioDecoder?.release();
    audioPlayer?.release();
    state = MediaPlayerState.defunct;
    lastError = Void();
    notifyListeners();
  }

  @override
  void replay() {
    stop();
    play();
  }

  @override
  void seek({Duration to}) {
    seekPositionCounter = _StopwatchWithOffset(to);
  }

  @override
  Duration get seekPosition => seekPositionCounter.elapsed;

  @override
  void setForwardBufferSize(Duration forwardBufferSize) {
    buffersController.setForwardBufferSize(forwardBufferSize);
  }

  @override
  void trySoftBufferingAgain() {
    isSoftBufferingEnabled = true;
    doSoftBufferingIfEnabled();
    notifyListeners();
  }

  @override
  RenderingInstructions getCurrentVectorFrame([bool pushAudio = false]) {
    final mediaPage = updateAndReturnVideoFinishedStatus()
        ? buffersController.getLastMediaPage()
        : buffersController.getMediaPageAt(
            seekPosition,
            whenNeedsSoftBuffering: doSoftBufferingIfEnabled,
            whenNeedsFullBuffering: doFullBuffering,
          );

    if (mediaPage.isVoid) return RenderingInstructions();

    bool audioWasPushed =
        mediaPageWhoseAudioWasLastPushed.headerEquals(mediaPage.header);
    if (!audioWasPushed && pushAudio) {
      audioPlayer?.writeToBuffer(mediaPage.decodedAudio);
      mediaPageWhoseAudioWasLastPushed = mediaPage;
    }

    return mediaPage.vectorFrame;
  }

  @override
  RenderingInstructions getCurrentVectorFrameAndPushAudio() {
    return getCurrentVectorFrame(true);
  }

  bool updateAndReturnVideoFinishedStatus() {
    bool finished =
        videoDuration > Duration.zero && seekPosition >= videoDuration;
    if (finished) pause();

    return finished;
  }

  Future<void> doFullBuffering() async {
    try {
      buffersController.clearBuffers();
      final lastState = state;
      state = MediaPlayerState.buffering;
      notifyListeners();
      await fetchAndQueueMediaPagesInRange(
          seekPosition, seekPosition + buffersController.sizeOfForwardBuffer);
      state = lastState;
      audioDecoder?.decode(Uint8List(0));
      notifyListeners();
    } catch (e) {
      lastError = e;
      state = MediaPlayerState.defunct;
      videoReader.release();
      audioDecoder?.release();
      audioPlayer?.release();
      notifyListeners();
    }
  }

  Future<void> doSoftBufferingIfEnabled() async {
    if (isSoftBufferingEnabled) {
      try {
        await fetchAndQueueMediaPagesInRange(
            buffersController.endSeekPositionOfTheLastMediaPageInQueue,
            buffersController.endSeekPositionOfTheLastMediaPageInQueue +
                buffersController
                    .getSizeOfFowardBufferSpaceToFill(seekPosition));
      } catch (e) {
        lastError = e;
        isSoftBufferingEnabled = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchAndQueueMediaPagesInRange(
    Duration start,
    Duration end,
  ) async {
    final returnedMediaPages =
        await videoReader.getMediaPagesInRange(start, end);
    for (var mediaPage in returnedMediaPages) {
      _MediaPageReadyToPlay decodedMediaPage =
          _MediaPageReadyToPlay.voidInstance();

      if (mediaPage.isVoid) {
        decodedMediaPage = recreateLostMediaPage();
        if (decodedMediaPage.isVoid) continue;
      } else {
        lastQueuedNonVoidMediaPage = mediaPage;

        var decodedAudio = Uint8List(0);
        if (mediaPage.compressedAudioData.isNotEmpty) {
          decodedAudio = audioDecoder?.decode(mediaPage.compressedAudioData) ??
              Uint8List(0);
        }

        decodedMediaPage =
            _MediaPageReadyToPlay(mediaPage.header, decodedAudio);
      }

      buffersController.queueMediaPage(
          decodedMediaPage,
          buffersController.endSeekPositionOfTheLastMediaPageInQueue,
          Duration(milliseconds: decodedMediaPage.header.pageDurationInMillis));
    }
  }

  _MediaPageReadyToPlay recreateLostMediaPage() {
    if (lastQueuedNonVoidMediaPage.isVoid)
      return _MediaPageReadyToPlay.voidInstance();

    final recreatedAudio = audioDecoder?.decode(Uint8List(0)) ?? Uint8List(0);
    return _MediaPageReadyToPlay(
        lastQueuedNonVoidMediaPage.header, recreatedAudio);
  }
}

class _StopwatchWithOffset implements Stopwatch {
  final Duration _offset;
  final Stopwatch _counter = Stopwatch();

  _StopwatchWithOffset(this._offset) : assert(_offset != null);

  @override
  Duration get elapsed => _offset + _counter.elapsed;

  @override
  int get elapsedMicroseconds => elapsed.inMicroseconds;

  @override
  int get elapsedMilliseconds => elapsed.inMilliseconds;

  @override
  int get elapsedTicks => _counter.elapsedTicks;

  @override
  int get frequency => _counter.frequency;

  @override
  bool get isRunning => _counter.isRunning;

  @override
  void reset() => _counter.reset();

  @override
  void start() => _counter.start();

  @override
  void stop() => _counter.stop();
}

/// Controlls the forward and backward buffers of a MediaPlayer.
class _MediaPageBuffersController {
  Duration seventyPercentOf(Duration duration) => duration * 0.7;

  final TimedMediaQueue<_MediaPageReadyToPlay> _mediaQueue =
      TimedMediaQueue.makeEmptyQueue();

  Duration _sizeOfBackwardBuffer = Duration(seconds: 10);
  Duration _sizeOfForwardBuffer = Duration(seconds: 15);

  void setForwardBufferSize(Duration size) {
    _sizeOfBackwardBuffer = seventyPercentOf(size);
    _sizeOfForwardBuffer = size;
  }

  Duration get sizeOfForwardBuffer => _sizeOfForwardBuffer;

  Duration getSizeOfFowardBufferSpaceToFill(Duration seekPosition) {
    final usedForwardBufferSpace =
        endSeekPositionOfTheLastMediaPageInQueue - seekPosition;

    return _sizeOfForwardBuffer - usedForwardBufferSpace;
  }

  Duration get endSeekPositionOfTheLastMediaPageInQueue {
    if (_mediaQueue.isEmpty) return Duration.zero;

    return _mediaQueue.lastItem.endSeekPosition;
  }

  _MediaPageReadyToPlay getLastMediaPage() {
    try {
      return _mediaQueue.lastItem.media;
    } catch (e) {
      return _MediaPageReadyToPlay.voidInstance();
    }
  }

  _MediaPageReadyToPlay getMediaPageAt(Duration seekPosition,
      {@required VoidCallback whenNeedsSoftBuffering,
      @required VoidCallback whenNeedsFullBuffering}) {
    final ret = _mediaQueue.getMediaAt(seekPosition,
        orElse: () => _MediaPageReadyToPlay.voidInstance());

    if (ret.isVoid) {
      whenNeedsFullBuffering();
      return ret;
    }

    // Check if soft buffering is needed.
    final usedForwardBufferSpace =
        endSeekPositionOfTheLastMediaPageInQueue - seekPosition;
    if (usedForwardBufferSpace < seventyPercentOf(_sizeOfForwardBuffer))
      whenNeedsSoftBuffering();

    // Make sure the backward buffer is not holding media more than its capacity.
    final usedBackwardBufferSpace =
        seekPosition - _mediaQueue.firstItem.startSeekPosition;
    if (usedBackwardBufferSpace > _sizeOfBackwardBuffer) {
      final lengthInFrontToRemove =
          usedBackwardBufferSpace - _sizeOfBackwardBuffer;
      _mediaQueue.removeFrontWithLength(lengthInFrontToRemove);
    }

    return ret;
  }

  void queueMediaPage(_MediaPageReadyToPlay mediaPage,
      Duration startSeekPosition, Duration mediaLength) {
    _mediaQueue.add(mediaPage, startSeekPosition, mediaLength);
  }

  void clearBuffers() {
    _mediaQueue.clear();
  }
}

class _MediaPageReadyToPlay {
  final MediaPageHeader header;
  final Uint8List decodedAudio;

  _MediaPageReadyToPlay(this.header, this.decodedAudio);

  bool get isVoid => this.vectorFrame == null;

  RenderingInstructions get vectorFrame => header?.vectorFrame;

  bool headerEquals(MediaPageHeader otherHeader) => this.header == otherHeader;

  factory _MediaPageReadyToPlay.voidInstance() =>
      _MediaPageReadyToPlay(null, Uint8List(0));
}
