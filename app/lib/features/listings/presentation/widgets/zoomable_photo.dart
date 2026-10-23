import 'package:flutter/material.dart';

import 'listing_photo.dart';

/// One photo of the full-screen gallery that zooms: pinch (or the mouse
/// wheel) from 1x to 4x, and a double tap zooms 2.5x where it was tapped,
/// or back out. [onZoomChanged] says when the photo leaves or returns to
/// 1x, so the gallery stops swiping between photos while one is zoomed
/// and a drag moves the photo instead.
class ZoomablePhoto extends StatefulWidget {
  const ZoomablePhoto({required this.url, this.onZoomChanged, super.key});

  final String url;
  final ValueChanged<bool>? onZoomChanged;

  static const maxScale = 4.0;
  static const doubleTapScale = 2.5;

  @override
  State<ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(_animate);
  Animation<Matrix4>? _tween;
  var _zoomed = false;
  var _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_reportZoom);
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _animate() {
    final tween = _tween;
    if (tween != null) _transform.value = tween.value;
  }

  void _reportZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged?.call(zoomed);
  }

  void _toggleZoom() {
    const scale = ZoomablePhoto.doubleTapScale;
    // Zoomed in around the tapped point: it stays under the finger.
    final target = _zoomed
        ? Matrix4.identity()
        : (Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(
            -_tapAt.dx * (scale - 1),
            -_tapAt.dy * (scale - 1),
            0,
          ));
    _tween = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOut));
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _tapAt = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        onInteractionStart: (_) => _animation.stop(),
        maxScale: ZoomablePhoto.maxScale,
        child: ListingPhoto(url: widget.url, fit: BoxFit.contain),
      ),
    );
  }
}
