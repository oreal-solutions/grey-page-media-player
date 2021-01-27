import 'package:flutter/foundation.dart';
import 'package:grey_page_media_player/src/audio/opus16_decoder.dart';
import 'package:grey_page_media_player/src/audio/pcm16_audio_player.dart';
import 'package:grey_page_media_player/src/readers/video_reader.dart';
import 'package:npxl_video/generated/npxl_video.pb.dart';

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
/// A soft seek is any seek is that is not a hard seek. That is any
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
/// will continue playing in [MediaPlayerState.playingWithNoSoftBuffering]
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
  /// consecutive times, i.e the audio frame is written only once in the duration the
  /// vector frame is displayed on screen.
  RenderingInstructions getCurrentVectorFrameAndPushAudio();

  /// Sets the size of the forward buffer.
  void setForwardBufferSize(Duration forwardBufferSize);

  /// Tells the [MediaPlayer] to attempt soft buffering again.
  ///
  /// This should be done when the [MediaPlayer] is in a
  /// [MediaPlayerState.playingWithNoSoftBuffering] state.
  void trySoftBufferingAgain();

  /// Release the given [VideoReader], [Opus16Decoder], and [PCM16AudioPlayer].
  ///
  /// After calling this method the [MediaPlayer] will be in a [MediaPlayerState.defunct]
  /// state.
  void release();

  /// Builds and returns an uninitialised [MediaPlayer] instance.
  factory MediaPlayer.makeInstance() {
    throw UnimplementedError();
  }
}

enum MediaPlayerState {
  /// The [MediaPlayer] is playing the video.
  playing,

  /// The [MediaPlayer] is playing the video but does not run
  /// the soft buffering algorithm when it is supposed to.
  ///
  /// This happens when the soft buffering coroutine catches
  /// an error from the provided [VideoReader].
  playingWithNoSoftBuffering,

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
