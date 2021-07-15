import 'dart:collection';

import 'package:flutter/foundation.dart';

class TimedMediaQueueItem<T> {
  /// The seek position in the video this media item starts at.
  final Duration startSeekPosition;

  /// The seek position in the video this media item ends at.
  final Duration endSeekPosition;

  final Duration mediaLength;
  final T media;

  TimedMediaQueueItem(this.media, this.startSeekPosition, this.mediaLength)
      : endSeekPosition = startSeekPosition + mediaLength;

  /// Returns true if [seekPosition] is in the range of this
  /// media item.
  bool isInSeekPosition(Duration seekPosition) {
    return seekPosition >= startSeekPosition && seekPosition < endSeekPosition;
  }
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

  /// Removes the first items in the queue whose combined lengths equals [length].
  void removeFrontWithLength(Duration length);

  /// Removes the last items in the queue whose combined length equals [length].
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
    return descendToMediaItemAt(
      seekPosition,
      queueStartIndex: 0,
      queueExclusiveEndIndex: queue.length,
      orElse: orElse,
    );
  }

  @override
  List<T> getMediaInRange(Duration inclusiveStart, Duration exclusiveEnd) {
    List<TimedMediaQueueItem<T>> ret;

    int lowerIndex = -1;
    int higherIndex = -1;

    try {
      lowerIndex =
          getLowerIndexForDurationRange(inclusiveStart, 0, queue.length);
    } catch (_) {}

    try {
      higherIndex =
          getHigherIndexForDurationInRange(exclusiveEnd, 0, queue.length);
    } catch (_) {}

    if (lowerIndex == -1 && higherIndex != -1)
      ret = queue.toList().sublist(0, higherIndex);
    else if (lowerIndex == -1 && higherIndex == -1)
      ret = [];
    else if (lowerIndex != -1 && higherIndex == -1)
      ret = queue.toList().sublist(lowerIndex);
    else
      ret = queue.toList().sublist(lowerIndex, higherIndex);

    return ret.map((e) => e.media).toList();
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

  T descendToMediaItemAt(
    Duration seekPosition, {
    @required int queueStartIndex,
    @required int queueExclusiveEndIndex,
    @required OrElse<T> orElse,
  }) {
    if (queueStartIndex == queueExclusiveEndIndex) {
      return orElse();
    } else if (queueExclusiveEndIndex - queueStartIndex == 1) {
      final mediaItem = queue.elementAt(queueStartIndex);
      return mediaItem.isInSeekPosition(seekPosition)
          ? mediaItem.media
          : orElse();
    }

    final midIndex = queueStartIndex +
        ((queueExclusiveEndIndex - queueStartIndex) / 2).floor();
    final midItem = queue.elementAt(midIndex);

    if (seekPosition < midItem.startSeekPosition) {
      return descendToMediaItemAt(
        seekPosition,
        queueStartIndex: queueStartIndex,
        queueExclusiveEndIndex: midIndex,
        orElse: orElse,
      );
    } else if (midItem.isInSeekPosition(seekPosition)) {
      return midItem.media;
    } else {
      return descendToMediaItemAt(
        seekPosition,
        queueStartIndex: midIndex,
        queueExclusiveEndIndex: queueExclusiveEndIndex,
        orElse: orElse,
      );
    }
  }

  int getLowerIndexForDurationRange(Duration inclusiveStartDuration,
      int queueStartIndex, int queueExclusiveEndIndex) {
    if (queueStartIndex == queueExclusiveEndIndex) {
      throw _CannotFindLowerIndexError();
    } else if (queueExclusiveEndIndex - queueStartIndex == 1) {
      if (queue
          .elementAt(queueStartIndex)
          .isInSeekPosition(inclusiveStartDuration)) {
        return queueStartIndex;
      }

      throw _CannotFindLowerIndexError();
    }

    final midIndex = queueStartIndex +
        ((queueExclusiveEndIndex - queueStartIndex) / 2).floor();
    final midItem = queue.elementAt(midIndex);
    if (inclusiveStartDuration < midItem.startSeekPosition) {
      return getLowerIndexForDurationRange(
          inclusiveStartDuration, queueStartIndex, midIndex);
    } else if (midItem.isInSeekPosition(inclusiveStartDuration)) {
      return midIndex;
    } else {
      // else if midItem.endSeekPosition >= inclusiveStartDuration

      // Note that we add one because we already know that the mid item
      // is not a candidate.
      return getLowerIndexForDurationRange(
          inclusiveStartDuration, midIndex + 1, queueExclusiveEndIndex);
    }
  }

  int getHigherIndexForDurationInRange(Duration exclusiveEndDuration,
      int queueStartIndex, int queueExclusiveEndIndex) {
    if (queueStartIndex == queueExclusiveEndIndex) {
      throw _CannotFindHigherIndexError();
    } else if (queueExclusiveEndIndex - queueStartIndex == 1) {
      if (queue
          .elementAt(queueStartIndex)
          .isInSeekPosition(exclusiveEndDuration)) {
        return queueExclusiveEndIndex;
      }

      throw _CannotFindHigherIndexError();
    }

    final midIndex = queueStartIndex +
        ((queueExclusiveEndIndex - queueStartIndex) / 2).floor();
    final midItem = queue.elementAt(midIndex);

    if (exclusiveEndDuration > midItem.endSeekPosition) {
      return getHigherIndexForDurationInRange(
          exclusiveEndDuration, midIndex + 1, queueExclusiveEndIndex);
    } else if (exclusiveEndDuration == midItem.endSeekPosition ||
        midItem.isInSeekPosition(exclusiveEndDuration)) {
      return midIndex + 1;
    } else if (exclusiveEndDuration == midItem.startSeekPosition) {
      return midIndex;
    } else {
      // else if exclusiveEndDuration < midItem.startSeekPosition
      return getHigherIndexForDurationInRange(
          exclusiveEndDuration, queueStartIndex, midIndex);
    }
  }
}

class _CannotFindLowerIndexError extends Error {
  @override
  String toString() => "Cannot find lower index.";
}

class _CannotFindHigherIndexError extends Error {
  @override
  String toString() => "Cannot find higher index.";
}
