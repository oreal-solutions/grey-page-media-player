import 'dart:math';
import 'dart:ui';

import 'package:grey_page_media_player/src/utls/rendering_utls.dart';
import 'package:test/test.dart';

void main() {
  group("computeRenderableSurface", () {
    const source = Size(6, 5);

    test(
        "Should return {target.width, reducedHeigfht} if target.width is the limiting dimension",
        () {
      const target = Size(12, 20);
      expect(computeRenderableSurface(source, target), Size(12, 10));
    });

    test(
        "Should return {target.width, target.height} is source and target have equal dimensions",
        () {
      expect(computeRenderableSurface(source, source), source);
    });

    test(
        "Should return {reducedWidth, target.height} if target.height is the limiting dimension",
        () {
      const target = Size(20, 10);
      expect(computeRenderableSurface(source, target), Size(12, 10));
    });
  });

  group("computeScaleFactor", () {
    test("Should return correct scale factor", () {
      final random = Random();
      final subject = Size(random.nextDouble(), random.nextDouble());
      final base = Size(random.nextDouble(), random.nextDouble());

      final ret = computeScaleFactor(subject, base);
      expect(
          ret,
          (subject.width * subject.width + subject.height * subject.height) /
              (base.width * base.width + base.height * base.height));
    });
  });
}
