import 'dart:collection';

import 'package:flutter/foundation.dart';

class TimedMediaQueueItem<T> {
  /// The seek position in the video this media item is in.
  final Duration startSeekPosition;

  /// The duration of this media item.
  final Duration mediaLength;

  final T media;

  TimedMediaQueueItem(this.media, this.startSeekPosition, this.mediaLength);

  /// Returns true if [seekPosition] is in the range of this
  /// media item.
  bool isInSeekPosition(Duration seekPosition) {
    return seekPosition >= startSeekPosition &&
        seekPosition < startSeekPosition + mediaLength;
  }

  Duration get lengthOfMediaTillFar => startSeekPosition + mediaLength;
}

typedef T OrElse<T>();

/// Stores a queue of [T] items in timed ranges.
///
/// This queue is meant to be used to store Media Pages of a video by wrapping
/// them in [TimedMediaQueueItem].
///
/// The generic [T] is to allow for the storing of different types of Media
/// Pages, e.g encoded and decoded Media Pages.
///
/// A [TimedMediaQueueItem] has a startSeekPosition, i.e where it is in the
/// video, and a length, i.e how long it is to be played.
abstract class TimedMediaQueue<T> {
  /// Returns the first [T] item whose [TimedMediaQueueItem] is in the given
  /// [seekPosition].
  ///
  /// [orElse] will be called this item is not found.
  T getMediaAt(Duration seekPosition, {@required OrElse<T> orElse});

  /// Returns the [T] items in the given range.
  List<T> getMediaInRange(Duration inclusiveStart, Duration exclusiveEnd);

  /// Removes the items in the queue whose combined lengths equals [length].
  void removeFrontWithLength(Duration length);

  /// Removes the last items in the queue whose combined length equals [lenght].
  void removeBackWithLength(Duration length);

  /// Clears the collection.
  void clear();

  /// Pushes [media] at the back of this queue.
  void add(T media, Duration startSeekPosition, Duration mediaLength);

  /// The first item in the queue.
  TimedMediaQueueItem<T> get firstItem;

  /// The last item in the queue.
  TimedMediaQueueItem<T> get lastItem;

  bool get isEmpty;

  bool get isNotEmpty;

  factory TimedMediaQueue.makeEmptyQueue() {
    return _TimedMediaQueue();
  }
}

class _TimedMediaQueue<T> implements TimedMediaQueue<T> {
  final Queue<TimedMediaQueueItem<T>> queue = Queue();

  @override
  void add(media, Duration startSeekPosition, Duration mediaLength) {
    queue.add(TimedMediaQueueItem(media, startSeekPosition, mediaLength));
  }

  @override
  void clear() {
    queue.clear();
  }

  @override
  TimedMediaQueueItem<T> get firstItem => queue.first;

  @override
  TimedMediaQueueItem<T> get lastItem => queue.last;

  @override
  T getMediaAt(Duration seekPosition, {OrElse<T> orElse}) {
    final ret = queue
        .firstWhere((item) => item.isInSeekPosition(seekPosition),
            orElse: () => null)
        ?.media;

    if (ret == null)
      return orElse();
    else
      return ret;
  }

  List<T> getMediaInRange(Duration inclusiveStart, Duration exclusiveEnd) {
    // TODO: Optimise for many media items by implementing some specialised form of binary searching
    final debug = queue.toList();
    final ret = queue
        .where((item) {
          return (inclusiveStart >= item.startSeekPosition &&
                  item.lengthOfMediaTillFar > inclusiveStart) ||
              (item.startSeekPosition >= inclusiveStart &&
                  item.lengthOfMediaTillFar < exclusiveEnd) ||
              (exclusiveEnd >= item.startSeekPosition &&
                  exclusiveEnd < item.lengthOfMediaTillFar);
        })
        .map((item) => item.media)
        .toList();

    return ret;
  }

  @override
  bool get isEmpty => queue.isEmpty;

  @override
  bool get isNotEmpty => queue.isNotEmpty;

  @override
  void removeBackWithLength(Duration length) {
    int numberofBackItemsToRemove = 0;
    Duration combinedBackItemsDuration = Duration.zero;

    for (var item in queue.toList().reversed) {
      combinedBackItemsDuration += item.mediaLength;
      if (combinedBackItemsDuration <= length)
        numberofBackItemsToRemove++;
      else
        break;
    }

    for (int i = 0; i < numberofBackItemsToRemove; i++) queue.removeLast();
  }

  @override
  void removeFrontWithLength(Duration length) {
    int numberOfFrontItemsToRemove = 0;
    Duration combinedFrontItemsDuration = Duration.zero;

    for (var item in queue) {
      combinedFrontItemsDuration += item.mediaLength;
      if (combinedFrontItemsDuration <= length)
        numberOfFrontItemsToRemove++;
      else
        break;
    }

    for (int i = 0; i < numberOfFrontItemsToRemove; i++) queue.removeFirst();
  }
}
