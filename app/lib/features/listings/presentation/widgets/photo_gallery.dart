import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../listing_detail_text.dart';
import '../photo_viewer_args.dart';
import 'listing_photo.dart';
import 'zoomable_photo.dart';
import '../../../../core/localization/localizations.dart';

/// All the listing's photos: swipe or use the arrows, tap to see them
/// full screen.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({
    required this.listingId,
    required this.images,
    super.key,
  });

  final String listingId;
  final List<String> images;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // A route of its own (not a bare Navigator push), so the browser's
  // history has an entry for it: the back gesture closes the photos
  // instead of leaving the listing.
  void _openFullScreen() => context.push(
    AppRoutes.listingPhotos(widget.listingId),
    extra: PhotoViewerArgs(images: widget.images, index: _index).toExtra(),
  );

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: images.isEmpty
            ? const ListingPhoto()
            : Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: _openFullScreen,
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: images.length,
                      onPageChanged: (index) => setState(() => _index = index),
                      itemBuilder: (_, index) =>
                          ListingPhoto(url: images[index]),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _RoundButton(
                      icon: Icons.fullscreen,
                      tooltip: context.strings.enlargePhotos,
                      onPressed: _openFullScreen,
                    ),
                  ),
                  if (images.length > 1)
                    _GalleryControls(
                      index: _index,
                      count: images.length,
                      controller: _controller,
                    ),
                ],
              ),
      ),
    );
  }
}

/// Arrows on the sides and the "3 / 12" counter. The arrows matter on a
/// computer, where a mouse can't swipe.
class _GalleryControls extends StatelessWidget {
  const _GalleryControls({
    required this.index,
    required this.count,
    required this.controller,
  });

  final int index;
  final int count;
  final PageController controller;

  void _go(int page) => controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (index > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: _RoundButton(
              icon: Icons.chevron_left,
              tooltip: context.strings.previousPhoto,
              onPressed: () => _go(index - 1),
            ),
          ),
        if (index < count - 1)
          Align(
            alignment: Alignment.centerRight,
            child: _RoundButton(
              icon: Icons.chevron_right,
              tooltip: context.strings.nextPhoto,
              onPressed: () => _go(index + 1),
            ),
          ),
        Positioned(
          right: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.photoCounterScrim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                photoCounterText(index, count),
                style: const TextStyle(color: AppColors.onPhoto),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.photoControlScrim,
          foregroundColor: AppColors.onPhoto,
        ),
      ),
    );
  }
}

/// The photos full screen (route `/deals/<id>/photos`), each one zoomable
/// (pinch, mouse wheel or double tap).
class FullScreenGallery extends StatefulWidget {
  const FullScreenGallery({
    required this.listingId,
    required this.args,
    super.key,
  });

  final String listingId;
  final PhotoViewerArgs args;

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late final _controller = PageController(initialPage: widget.args.index);
  late var _index = widget.args.index;
  // While a photo is zoomed a drag moves it, not to the next photo.
  var _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setZoomed(bool zoomed) {
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.args.images;

    return Scaffold(
      backgroundColor: AppColors.photoBackdrop,
      appBar: AppBar(
        leading: CloseButton(
          onPressed: () => goBack(
            context,
            fallback: AppRoutes.listingDetail(widget.listingId),
          ),
        ),
        backgroundColor: AppColors.photoBackdrop,
        foregroundColor: AppColors.onPhoto,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: AppColors.photoBackdrop,
        ),
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: images.length,
              // The arrows still turn the page; the new photo starts at 1x.
              onPageChanged: (index) => setState(() {
                _index = index;
                _zoomed = false;
              }),
              itemBuilder: (_, index) =>
                  ZoomablePhoto(url: images[index], onZoomChanged: _setZoomed),
            ),
            if (images.length > 1)
              _GalleryControls(
                index: _index,
                count: images.length,
                controller: _controller,
              ),
          ],
        ),
      ),
    );
  }
}
