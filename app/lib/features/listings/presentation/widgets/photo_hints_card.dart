import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/listing.dart';
import '../photo_hints_text.dart';
import '../photo_viewer_args.dart';

/// What the image model may have seen in the listing's photos (P.2): each
/// hint opens its photo, so the person judges it. Nothing when there is
/// none; never part of a score.
class PhotoHintsCard extends StatelessWidget {
  const PhotoHintsCard({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final lines = photoHintLines(listing, language: context.language);
    if (lines.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: context.strings.photoHintsTitle,
      footnote: context.strings.photoHintsNote,
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
      ],
    );
  }
}
