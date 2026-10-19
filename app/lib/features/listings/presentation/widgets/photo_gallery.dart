import 'package:flutter/material.dart';

import '../listing_detail_text.dart';
import 'listing_photo.dart';

/// All the listing's photos: swipe or use the arrows, tap to see them
/// full screen.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({required this.images, super.key});

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

  void _openFullScreen() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _FullScreenGallery(images: widget.images, initialIndex: _index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
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
              tooltip: 'Foto anterior',
              onPressed: () => _go(index - 1),
            ),
          ),
        if (index < count - 1)
          Align(
            alignment: Alignment.centerRight,
            child: _RoundButton(
              icon: Icons.chevron_right,
              tooltip: 'Foto seguinte',
              onPressed: () => _go(index + 1),
            ),
          ),
        Positioned(
          right: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                photoCounterText(index, count),
                style: const TextStyle(color: Colors.white),
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
          backgroundColor: Colors.black45,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late var _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (_, index) =>
                  ListingPhoto(url: images[index], fit: BoxFit.contain),
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
