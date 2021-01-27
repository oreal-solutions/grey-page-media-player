import 'dart:typed_data';

import 'package:npxl_video/generated/npxl_video.pb.dart';

/// An [Opus16Decoder] decodes opus16 audio frames.
abstract class Opus16Decoder {
  /// Decodes the given audio frame into a pcm16 audio frame.
  ///
  /// Lost frames can be replaced with loss concealment by passing
  /// [encodedOpus16AudioData] as an empty list. When this is done,
  /// this method will return decoded audio data that best estimates
  /// the audio the lost frame would have had.
  ///
  /// Throws [OpusDecodingError] when it fails to decode the frame.
  ///
  /// Throws [DefuctOpusDecoderError] when the decoder is in such a bad
  /// state that it should no longer be used.
  Uint8List decode(Uint8List encodedOpus16AudioData);

  /// Release all resources used by the decoder.
  ///
  /// This is called by a [MediaPlayer] when it is discarding this
  /// decoder.
  void release();

  /// Initialises the decoder with the given [AudioProperties].
  ///
  /// This is called by a [MediaPlayer] prior to using this decoder.
  Future<void> initialise(AudioProperties audioProperties);
}

/// Error thrown when an audio frame could not be decoded.
class OpusDecodingError extends Error {
  final String message;
  OpusDecodingError([this.message = '']);
}

/// Error thrown when an [DisfuctOpusDecoderError] is in such a bad state
/// that it should no longer be used.
class DefuctOpusDecoderError extends Error {
  final String message;
  DefuctOpusDecoderError([this.message = '']);
}
