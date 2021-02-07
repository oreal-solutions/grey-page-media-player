import 'dart:ui';

/// Computes the maximum size the [source] surface can be scaled to inside
/// [target] while maintaining its aspect ratio.
///
/// [source] is the size of the source surface.
/// [target] is the size of the traget surface.
Size computeRenderableSurface(Size source, Size target) {
  // We will use the gradient to maintain the aspect ratio.
  //
  // A bit of maths:
  //
  // The gradient of a straight line is defined as:
  //    m = (y2 - y1)/(x2 - x1)
  // If we were to place the source rectangle in a 2D cartesian space, axis aligned, with its
  // bottom left corner on the origin then (x1, y1) will be equal to (0; 0). We can therefore
  // simplify the equation to:
  //    m = (y2 - 0)/(x2 - 0) = (y2)/(x2) = height/width
  //        where width and height is the respective width and height of the rectangle.
  //
  // This, therefore, allows the following two equations to hold true:
  //    height = m*width
  //    width = (1/m)*height
  //

  final gradient = source.height / source.width;

  // We start by assuming that the width of target is the limiting dimension.
  final reducedHeight = gradient * target.width;
  if (reducedHeight <= target.height) {
    return Size(target.width, reducedHeight);
  } else {
    // The width of target is not the limiting dimension. The height of target must be the
    // limiting dimension then.
    final reducedWidth = (1 / gradient) * target.height;
    return Size(reducedWidth, target.height);
  }
}

/// Computes the ratio of the size of the diagonal of the [subject] rectangle
/// to the size of the diagonal of the base rectangle.
double computeScaleFactor(Size subject, Size base) {
  return (subject.width * subject.width + subject.height * subject.height) /
      (base.width * base.width + base.height * base.height);
}
