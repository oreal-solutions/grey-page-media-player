import 'dart:typed_data';

import 'package:npxl_video/generated/npxl_video.pb.dart';

/// A [PCM16AudioPlayer] plays pcm16 audio frames to the devices'
/// speakers.
///
/// A [PCM16AudioPlayer] plays audio data from a buffer. That is,
/// when the buffer is empty the audio player pauses play and will
/// resume gain when the buffer has audio frames to play.
abstract class PCM16AudioPlayer {
  /// Add [pcm16AudioData] to the audio buffer.
  ///
  /// The audio frame will be queued for playing and will be played
  /// immediately after the audio frame that was queued just before
  /// it.
  ///
  /// To discard the queued audio frames and the one currently playing
  /// use [clearBuffer].
  void writeToBuffer(Uint8List pcm16AudioData);

  /// Discards the audio frame that is currently playing and all
  /// those that are pending.
  void clearBuffer();

  /// Release all resources used by this audio player.
  ///
  /// This is called by a [MediaPlayer] when it is discarding this
  /// audio player.
  void release();

  /// Initialises the audio player with the given [AudioProperties]
  ///
  /// This is called by a [MediaPlayer] prior to using this audio player.
  Future<void> initialise(AudioProperties audioProperties);
}
