import 'package:npxl_video/generated/npxl_video.pb.dart';
import 'package:npxl_video/npxl_video.dart';

/// A [VideoReader] provides all the video attributes and media
/// needed by a [MediaPlayer] to play the video.
///
/// These are:
///   1. The length of the video (duration)
///   2. The [AudioProperties] of the video
///   3. And the [ReadableMediaPage]s
///
abstract class VideoReader {
  /// Returns the duration of the video.
  ///
  /// The returned video duration is parsed from the videos' header.
  /// A [MediaPlayer] will need to increment the duration by itself
  /// if it recreates lost and corrupted media pages.
  ///
  /// If the duration of the video cannot be determined, for example
  /// when the video is being live streamed, then [Duration.zero]
  /// is returned.
  Future<Duration> getVideoDuration();

  /// Returns the videos' media pages that lie in the given duration
  /// range.
  ///
  /// Lost and corrupted Media Pages will have their positions filled
  /// with void [ReadableMediaPage]s.
  ///
  /// This method assumes that the first media page in the video is indeed
  /// the first media page. That is, there are no lost media pages before
  /// it.
  ///
  /// If the first media page in this range overlaps [start], it will also
  /// be returned. Likewise, if the last media page in this range overlaps
  /// [end], it will also be returned.
  Future<List<ReadableMediaPage>> getMediaPagesInRange(
      Duration start, Duration end);

  /// Returns the audio properties of the video.
  Future<AudioProperties> getAudioProperties();

  /// Initialises this video reader instance.
  ///
  /// This is called by a [MediaPlayer] prior to using this [VideoReader].
  Future<void> initialise();

  /// Release all resources used by this [VideoReader].
  ///
  /// This is called by a [MediaPlayer] when it is discarding this
  /// [VideoReader].
  void release();
}
