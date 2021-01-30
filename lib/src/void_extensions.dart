import 'package:npxl_video/generated/npxl_video.pb.dart';
import 'package:npxl_video/npxl_video.dart';

/// Void [RenderingInstructions] have no [Viewport].
///
/// [RenderingInstructions] should also be treated as void if the
/// [ReadableMediaPage] containing them is void.
extension VoidRenderingInstructions on RenderingInstructions {
  bool get isVoid => !this.hasViewport();
}

/// A void [ReadableMediaPage] has no header.
extension VoidReadableMediaPage on ReadableMediaPage {
  bool get isVoid => this.header == null;
}

class Void {
  bool get isVoid => true;
}

extension VoidDynamic on dynamic {
  bool get isVoid => this == null || (this is Void);
}
