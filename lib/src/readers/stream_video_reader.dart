import 'dart:io';
import 'dart:typed_data';

import 'package:grey_page_media_player/src/readers/timed_media_queue.dart';
import 'package:grey_page_media_player/src/readers/video_reader.dart';
import 'package:npxl_video/npxl_video.dart';
import 'package:npxl_video/generated/npxl_video.pb.dart';

/// Reads a video from a [RandomAccessByteInputStream].
///
/// TODO(Batandwa): Clean
class StreamVideoReader implements VideoReader {
  final RandomAccessByteInputStream source;
  final TimedMediaQueue<StreamReadableMediaPage> mediaPages =
      TimedMediaQueue.makeEmptyQueue();

  VideoHeader _header;
  RandomAccessByteInputStream _mediaPagesInputStream;

  StreamVideoReader(this.source);

  @override
  Future<AudioProperties> getAudioProperties() async {
    return _header.audioProperties;
  }

  @override
  Future<List<ReadableMediaPage>> getMediaPagesInRange(
      Duration inclusiveStart, Duration exclusiveEnd) async {
    final ret = <ReadableMediaPage>[];
    final mediaPagesInRange =
        mediaPages.getMediaInRange(inclusiveStart, exclusiveEnd);
    for (var mediaPage in mediaPagesInRange) {
      final audio = await mediaPage.compressedAudioStream
          .readBytes(0, mediaPage.sizeOfCompressedAudioInBytes);

      ret.add(ReadableMediaPage(mediaPage.header, audio));
    }

    return ret;
  }

  @override
  Future<Duration> getVideoDuration() async {
    return Duration(milliseconds: _header.videoDurationInMillis);
  }

  @override
  Future<void> initialise() async {
    await loadVideoHeader();
    for (var range in _header.mediaPageDataRanges) {
      await fetchAndRegisterMediaPageInRange(range);
    }
  }

  @override
  void release() {
    source.close();
  }

  Future<void> loadVideoHeader() async {
    if (source.numberOfReadableBytes < 5) throw ArgumentError('Bad video');

    final sizeOfVideoHeaderBinaryData = await source.readBytes(2, 2);
    final sizeOfVideoHeader =
        getUnsignedShortFromUint8List(sizeOfVideoHeaderBinaryData);

    final videoHeaderBinaryData = await source.readBytes(4, sizeOfVideoHeader);
    this._header = VideoHeader.fromBuffer(videoHeaderBinaryData);

    int offsetToFirstByteOfFirstMediaPage = 4 + sizeOfVideoHeader;
    _mediaPagesInputStream = SkippingRandomAccessByteInputStream(
        offsetToFirstByteOfFirstMediaPage, source);
  }

  Future<void> fetchAndRegisterMediaPageInRange(DataRange range) async {
    StreamReadableMediaPage mediaPage = StreamReadableMediaPage.voidInstance();

    try {
      final headerSize = getUnsignedShortFromUint8List(
          await _mediaPagesInputStream.readBytes(range.start + 2, 2));
      final headerBinaryData =
          await _mediaPagesInputStream.readBytes(range.start + 4, headerSize);

      final header = MediaPageHeader.fromBuffer(headerBinaryData);
      final compressedAudioStream = SkippingRandomAccessByteInputStream(
          range.start + 4 + headerSize, _mediaPagesInputStream);

      mediaPage = StreamReadableMediaPage(header, compressedAudioStream,
          range.end - range.start - 4 - headerSize);
    } on IOException catch (e) {
      // Failed to fetch Media Page
      throw e;
    } catch (e) {
      // The media page must be corrupted.
      // We'll insert a void instance
    }

    Duration lastEndSeekPosition = Duration.zero;
    Duration durationOfLastRegisteredMediaPage = Duration.zero;
    try {
      void fetchLastMediaPageAttributes() {
        lastEndSeekPosition = mediaPages.lastItem.startSeekPosition +
            mediaPages.lastItem.mediaLength;
        durationOfLastRegisteredMediaPage = mediaPages.lastItem.mediaLength;
      }

      fetchLastMediaPageAttributes();

      // Add void Media Pages for missing media pages
      if (!mediaPage.isVoid && !mediaPages.lastItem.media.isVoid) {
        int numberOfMissingMediaPages = mediaPage.header.mediaPageNumber -
            mediaPages.lastItem.media.header.mediaPageNumber -
            1;

        if (numberOfMissingMediaPages.isNegative)
          throw 'Bad Media Page Ordering. A Media Page coming after this one has already been registered';

        while (numberOfMissingMediaPages > 0) {
          mediaPages.add(StreamReadableMediaPage.voidInstance(),
              lastEndSeekPosition, durationOfLastRegisteredMediaPage);
          numberOfMissingMediaPages--;
          fetchLastMediaPageAttributes();
        }
      }
    } catch (_) {
      // We'll insert the media page we currently have.
    }

    final mediaPageDuration = mediaPage.isVoid
        ? durationOfLastRegisteredMediaPage
        : Duration(milliseconds: mediaPage.header.pageDurationInMillis);
    mediaPages.add(mediaPage, lastEndSeekPosition, mediaPageDuration);
  }

  static StreamVideoReader fromFile(String filePath) {
    final file = File(filePath);
    return StreamVideoReader(_FileRandomAccessByteInputStream(file.openSync()));
  }
}

class StreamReadableMediaPage {
  final MediaPageHeader header;
  final RandomAccessByteInputStream compressedAudioStream;
  final int sizeOfCompressedAudioInBytes;

  StreamReadableMediaPage(this.header, this.compressedAudioStream,
      this.sizeOfCompressedAudioInBytes);

  bool get isVoid => header == null;

  factory StreamReadableMediaPage.voidInstance() => StreamReadableMediaPage(
      null, InMemoryRandomAccessByteInputStream(Uint8List(0)), 0);
}

class _FileRandomAccessByteInputStream implements RandomAccessByteInputStream {
  final RandomAccessFile file;
  _FileRandomAccessByteInputStream(this.file);

  @override
  void close() {
    file.closeSync();
  }

  @override
  int get numberOfReadableBytes => file.lengthSync();

  @override
  Future<Uint8List> readBytes(int offset, int numberOfBytesToRead) {
    file.setPositionSync(offset);
    return file.read(numberOfBytesToRead);
  }
}
