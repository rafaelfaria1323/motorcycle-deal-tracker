import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/photo_exams_repository.dart';
import '../photo_exam_text.dart';
import '../photo_hints_text.dart';
import '../photo_viewer_args.dart';

/// What the image model may have seen in the listing's photos (P.2): each
/// hint opens its photo, so the person judges it. A signed-in account can
/// ask for every photo to be examined, not only the first ones (P.4).
/// Nothing when there is neither; never part of a score.
class PhotoHintsCard extends StatefulWidget {
  const PhotoHintsCard({super.key, required this.listing});

  final Listing listing;

  @override
  State<PhotoHintsCard> createState() => _PhotoHintsCardState();
}

class _PhotoHintsCardState extends State<PhotoHintsCard> {
  // The answer to a request made on this page.
  PhotoExam? _answer;
  var _busy = false;

  Future<void> _request() async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.strings;
    setState(() => _busy = true);
    try {
      final at = await getIt<PhotoExamsRepository>().request(widget.listing.id);
      // Null: every photo already was examined.
      final answer = at == null ? PhotoExam.done : PhotoExam.requested;
      if (mounted) setState(() => _answer = answer);
    } on PhotoExamLimit {
      messenger.showSnackBar(SnackBar(content: Text(strings.photoExamLimit)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(strings.photoExamFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final lines = photoHintLines(listing, language: context.language);

    return BlocBuilder<SessionCubit, SessionState>(
      bloc: getIt<SessionCubit>(),
      builder: (context, session) {
        var exam = _answer ?? photoExamOf(listing);
        // Only accounts can ask; anonymous visitors see the hints alone.
        if (exam == PhotoExam.available && !session.signedIn) {
          exam = PhotoExam.none;
        }
        if (lines.isEmpty && exam == PhotoExam.none) {
          return const SizedBox.shrink();
        }
        final strings = context.strings;

        return SectionCard(
          title: strings.photoHintsTitle,
          footnote: strings.photoHintsNote,
          children: [
            for (final line in lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.photo_outlined),
                title: Text(line.label),
                subtitle: Text(line.photoLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  AppRoutes.listingPhotos(listing.id),
                  extra: PhotoViewerArgs(
                    images: listing.images,
                    index: line.photo,
                  ).toExtra(),
                ),
              ),
            if (lines.isNotEmpty && exam != PhotoExam.none)
              const SizedBox(height: 8),
            switch (exam) {
              PhotoExam.none => const SizedBox.shrink(),
              PhotoExam.available => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.photoExamAvailable),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _request,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(strings.photoExamAction),
                  ),
                ],
              ),
              PhotoExam.requested => Text(strings.photoExamRequested),
              PhotoExam.done => Text(strings.photoExamDone),
            },
          ],
        );
      },
    );
  }
}
