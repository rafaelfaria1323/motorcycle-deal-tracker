import 'package:material_ui/material_ui.dart';

import '../../../../core/formatting/formatters.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../listings/presentation/widgets/listing_photo.dart';
import '../../domain/entities/shared_ad.dart';
import '../shared_ad_text.dart';

/// "Enviados do iPhone" (N.110): the ads the iPhone shortcut sent, waiting
/// to fill "Avaliar um anúncio"'s form.
class const SharedAdsInbox({
  required final List<SharedAd> ads,
  required final ValueChanged<SharedAd> onUse,
  required final ValueChanged<SharedAd> onDismiss,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SectionCard(
      title: strings.sharedAdsTitle,
      footnote: strings.sharedAdsIntro,
      children: [
        for (final ad in ads)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox.square(
              dimension: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ListingPhoto(
                  url: ad.photos.firstOrNull,
                  // Not the photo CDN's: its address takes no size.
                  fullSize: true,
                ),
              ),
            ),
            title: Text(
              sharedAdName(ad),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              strings.sharedAdLine(
                site: sharedAdSite(ad),
                date: Formatters.date(ad.receivedAt),
                photos: ad.photos.length,
              ),
            ),
            onTap: () => onUse(ad),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => onUse(ad),
                  child: Text(strings.sharedAdUse),
                ),
                IconButton(
                  tooltip: strings.sharedAdDismiss,
                  icon: const Icon(Icons.close),
                  onPressed: () => onDismiss(ad),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The used ad's photos, in a row under the form's fields.
class const SharedAdPhotos({required final List<String> photos, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.strings.sharedAdPhotos,
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 128,
              child: ListingPhoto(url: photos[index], fullSize: true),
            ),
          ),
        ),
      ),
    );
  }
}
