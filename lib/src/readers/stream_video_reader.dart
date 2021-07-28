import 'dart:io';
import 'dart:typed_data';

import 'package:grey_page_media_player/src/readers/timed_media_queue.dart';
import 'package:grey_page_media_player/src/readers/video_reader.dart';
import 'package:npxl_video/npxl_video.dart';
import 'package:npxl_video/generated/npxl_video.pb.dart';
import 'package:grey_page_media_player/src/void_extensions.dart';

/// Reads a video from a [RandomAccessByteInputStream].
///
/// TODO(Batandwa): Clean
class StreamVideoReader implements VideoReader {
  final RandomAccessByteInputStream source;
  final TimedMediaQueue<MediaPageHeader> mediaPageHeaders =
      TimedMediaQueue.makeEmptyQueue();

  VideoHeader _header;
  RandomAccessByteInputStream _mediaPagesInputStream;

  StreamVideoReader(this.source);

  @override
  Future<AudioProperties> getAudioProperties() async {
    return _header.audioProperties;
  }

  @override
  Future<List<ReadableMediaPageWithHeader>> getMediaPagesInRange(
      Duration inclusiveStart, Duration exclusiveEnd) async {
    final ret = <ReadableMediaPageWithHeader>[];
    final mediaPageHeadersInRange =
        mediaPageHeaders.getMediaInRange(inclusiveStart, exclusiveEnd);

    for (var mediaPageHeader in mediaPageHeadersInRange) {
      try {
        ret.add(await readMediaPageWithHeader(mediaPageHeader));
      } on IOException {
        rethrow;
      } catch (e) {
        // The media page must be corrupted, we therefore insert a void instance.
        ret.add(ReadableMediaPageWithHeader.voidInstance());
      }
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
    for (var mediaPageHeader in _header.mediaPageHeaders) {
      await queueMediaPageWithHeader(mediaPageHeader);
    }
  }

  @override
  void release() {
    source.close();
  }

  Future<ReadableMediaPageWithHeader> readMediaPageWithHeader(
      MediaPageHeader mediaPageHeader) async {
    final start = mediaPageHeader.mediaPageDataRange.start;
    final end = mediaPageHeader.mediaPageDataRange.end;
    final mediaPageBinaryData =
        await _mediaPagesInputStream.readBytes(start, end - start);

    return ReadableMediaPageWithHeader.from(
      header: mediaPageHeader,
      readableMediaPage: readMediaPage(mediaPageBinaryData),
    );
  }

  Future<void> loadVideoHeader() async {
    if (source.numberOfReadableBytes < 5) throw ArgumentError('Bad video');

    final sizeOfVideoHeaderBinaryData = await source.readBytes(2, 4);
    final sizeOfVideoHeader =
        getUnsigned32BitIntFromUint8List(sizeOfVideoHeaderBinaryData);

    final videoHeaderBinaryData = await source.readBytes(6, sizeOfVideoHeader);
    this._header = VideoHeader.fromBuffer(videoHeaderBinaryData);

    int offsetToFirstByteOfFirstMediaPage = 6 + sizeOfVideoHeader;
    _mediaPagesInputStream = SkippingRandomAccessByteInputStream(
        offsetToFirstByteOfFirstMediaPage, source);
  }

  Future<void> queueMediaPageWithHeader(MediaPageHeader header) async {
    Duration lastEndSeekPosition = Duration.zero;
    Duration durationOfLastRegisteredMediaPage = Duration.zero;
    try {
      void fetchLastMediaPageAttributes() {
        lastEndSeekPosition = mediaPageHeaders.lastItem.endSeekPosition;
        durationOfLastRegisteredMediaPage =
            mediaPageHeaders.lastItem.mediaLength;
      }

      fetchLastMediaPageAttributes();

      // Add void Media Pages for missing media pages
      if (mediaPageHeaders.lastItem.media.isNotVoid) {
        int numberOfMissingMediaPages = header.mediaPageNumber -
            mediaPageHeaders.lastItem.media.mediaPageNumber -
            1;

        if (numberOfMissingMediaPages.isNegative)
          throw 'Bad Media Page Ordering. A Media Page coming after this one has already been registered';

        while (numberOfMissingMediaPages > 0) {
          mediaPageHeaders.add(MediaPageHeader(), lastEndSeekPosition,
              durationOfLastRegisteredMediaPage);
          numberOfMissingMediaPages--;
          fetchLastMediaPageAttributes();
        }
      }
    } catch (_) {
      // There is no last item or there is bad media page ordering.
      // We'll insert the media page header we currently have.
    }

    mediaPageHeaders.add(
      header,
      lastEndSeekPosition,
      Duration(milliseconds: header.pageDurationInMillis),
    );
  }

  static StreamVideoReader fromFile(String filePath) {
    final file = File(filePath);
    return StreamVideoReader(FileRandomAccessByteInputStream(file.openSync()));
  }
}

class FileRandomAccessByteInputStream implements RandomAccessByteInputStream {
  final RandomAccessFile file;
  FileRandomAccessByteInputStream(this.file);

  @override
  void close() {
    file.closeSync();
  }

  @override
  int get numberOfReadableBytes => file.lengthSync();

  @override
  Future<Uint8List> readBytes(int offset, int numberOfBytesToRead) async {
    file.setPositionSync(offset);
    return file.readSync(numberOfBytesToRead);
  }
}
