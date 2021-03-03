import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:grey_page_media_player/src/media_player.dart';
import 'package:grey_page_media_player/src/utils/rendering_utils.dart';
import 'package:grey_page_media_player/src/void_extensions.dart';
import 'package:npxl_video/generated/npxl_video.pb.dart' as npxl;

typedef void OnPostRenderCallback();

class MediaPlayerView extends StatelessWidget {
  final MediaPlayer initialisedMediaPlayer;
  final bool muteAudio;
  final Size size;
  final OnPostRenderCallback onPostRender;
  final BorderRadius borderRadius;
  MediaPlayerView(
      {@required this.initialisedMediaPlayer,
      this.muteAudio = false,
      this.size = Size.zero,
      this.onPostRender,
      this.borderRadius = BorderRadius.zero,
      Key key})
      : assert(initialisedMediaPlayer != null),
        assert(size != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return FrameRenderer(
      borderRadius: borderRadius,
      size: size,
      onPostRender: onPostRender,
      frameProvider: muteAudio
          ? MutedVideoPlaybackFrameProvider(initialisedMediaPlayer)
          : VideoPlaybackFrameProvider(initialisedMediaPlayer),
    );
  }
}

class FrameRenderer extends StatefulWidget {
  final FrameProvider frameProvider;
  final Size size;
  final OnPostRenderCallback onPostRender;
  final BorderRadius borderRadius;
  FrameRenderer(
      {@required this.frameProvider,
      this.size = Size.zero,
      this.onPostRender,
      this.borderRadius = BorderRadius.zero,
      Key key})
      : assert(frameProvider != null),
        assert(size != null),
        assert(borderRadius != null),
        super(key: key);

  @override
  State<StatefulWidget> createState() {
    return FrameRendererState();
  }
}

class FrameRendererState extends State<FrameRenderer> {
  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      setState(widget.onPostRender ?? () {});
    });

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: CustomPaint(
        size: widget.size,
        painter: FlutterPainter(
          frameProvider: widget.frameProvider,
        ),
      ),
    );
  }
}

class FlutterPainter extends CustomPainter {
  final FrameProvider frameProvider;
  FlutterPainter({@required this.frameProvider});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final frame = frameProvider.getCurrentFrame();
    if (frame.isVoid) return;

    paintBackgroundColor(canvas, canvasSize, frame.backgroundColor);

    final sourceDimensions = Size(frame.viewport.width, frame.viewport.height);
    final renderableCanvasSize =
        computeRenderableSurface(sourceDimensions, canvasSize);

    // Scale the source dimensions to align with those of the renderable dimentions.
    canvas.scale(renderableCanvasSize.width / sourceDimensions.width,
        renderableCanvasSize.height / sourceDimensions.height);

    // Translate the renderables to align with the top left corner of the source viewport.
    // If the viewport gives a positive x value we have to move the renderables to the
    // left, and vice versa. If the viewport gives a positive y value we have to move
    // the renderables upwards, and vice versa.
    canvas.translate(
        -frame.viewport.topLeftCorner.dx, -frame.viewport.topLeftCorner.dy);

    // Paint Paths
    frame.paths.forEach((path) {
      paintPath(canvas, path);
    });

    if (frame.hasPointer()) paintPointer(canvas, frame.pointer);
  }

  void paintBackgroundColor(Canvas canvas, Size canvasSize, npxl.Color color) {
    var paint = new Paint();
    paint.style = PaintingStyle.fill;
    paint.color = parseNpxlColor(color);
    Rect rect = new Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    canvas.drawRect(rect, paint);
  }

  void paintPath(Canvas canvas, npxl.Path path) {
    final paint = Paint();
    paint.strokeCap = StrokeCap.round;
    paint.strokeJoin = StrokeJoin.round;
    paint.style = PaintingStyle.stroke;
    paint.color = parseNpxlColor(path.color);
    paint.strokeWidth = path.strokeWidth;

    Path drawablePath = Path();
    final firstPoint = path.points.first;
    drawablePath.moveTo(firstPoint.coordinates.dx, firstPoint.coordinates.dy);
    path.points.sublist(1).forEach((pathPoint) {
      // TODO(Batandwa): Apply the pressure component.
      drawablePath.lineTo(pathPoint.coordinates.dx, pathPoint.coordinates.dy);
    });
    drawablePath.close();
    canvas.drawPath(drawablePath, paint);
  }

  void paintPointer(Canvas canvas, npxl.Pointer pointer) {
    // TODO(Batandwa): Implement
  }

  Color parseNpxlColor(npxl.Color color) {
    return Color(color.value);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

abstract class FrameProvider {
  npxl.RenderingInstructions getCurrentFrame();
}

class VideoPlaybackFrameProvider implements FrameProvider {
  final MediaPlayer mediaPlayer;
  VideoPlaybackFrameProvider(this.mediaPlayer);

  @override
  npxl.RenderingInstructions getCurrentFrame() {
    return mediaPlayer.getCurrentVectorFrameAndPushAudio();
  }
}

class MutedVideoPlaybackFrameProvider implements FrameProvider {
  final MediaPlayer mediaPlayer;
  MutedVideoPlaybackFrameProvider(this.mediaPlayer);

  @override
  npxl.RenderingInstructions getCurrentFrame() {
    return mediaPlayer.getCurrentVectorFrame();
  }
}
