import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../settings/domain/accounts_repository.dart';
import '../../domain/repositories/photo_marks_repository.dart';
import '../listing_detail_text.dart';
import '../photo_hints_text.dart';
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
/// (pinch, mouse wheel or double tap). Admins can also mark each of the
/// first [markablePhotos] as a problem or fine, for the image model to
/// learn from (P.3).
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
  // The admin's marks by photo; null: not an admin (or not loaded).
  Map<int, bool>? _marks;

  @override
  void initState() {
    super.initState();
    _loadMarks();
  }

  Future<void> _loadMarks() async {
    if (!getIt<SessionCubit>().state.signedIn) return;
    try {
      if (!await getIt<AccountsRepository>().isAdmin()) return;
      final marks = await getIt<PhotoMarksRepository>().marks(widget.listingId);
      if (mounted) setState(() => _marks = marks);
    } on Object {
      // Without the marks the photos are only shown, as for everyone.
    }
  }

  Future<void> _mark(int photo, bool? problem) async {
    final marks = _marks;
    if (marks == null) return;
    final before = marks[photo];
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.strings.photoMarkFailed;
    setState(() => _marks = _withMark(marks, photo, problem));
    try {
      await getIt<PhotoMarksRepository>().setMark(
        widget.listingId,
        photo,
        problem,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _marks = _withMark(_marks!, photo, before));
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  static Map<int, bool> _withMark(
    Map<int, bool> marks,
    int photo,
    bool? mark,
  ) => {
    for (final e in marks.entries)
      if (e.key != photo) e.key: e.value,
    if (mark != null) photo: mark,
  };

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
    final marks = _marks;

    return Scaffold(
      backgroundColor: AppColors.photoBackdrop,
      bottomNavigationBar: marks != null && _index < markablePhotos
          ? _PhotoMarkBar(
              mark: marks[_index],
              onChanged: (problem) => _mark(_index, problem),
            )
          : null,
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

/// An admin's mark on the photo shown: a problem or fine; tapping the one
/// chosen clears it.
class _PhotoMarkBar extends StatelessWidget {
  const _PhotoMarkBar({required this.mark, required this.onChanged});

  final bool? mark;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final mark = this.mark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.photoMarkTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onPhoto),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(strings.photoMarkProblem),
                  icon: const Icon(Icons.report_outlined),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(strings.photoMarkFine),
                  icon: const Icon(Icons.check),
                ),
              ],
              selected: {if (mark != null) mark},
              emptySelectionAllowed: true,
              onSelectionChanged: (selected) =>
                  onChanged(selected.isEmpty ? null : selected.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: AppColors.photoControlScrim,
                foregroundColor: AppColors.onPhoto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
