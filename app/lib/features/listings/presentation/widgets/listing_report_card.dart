import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/platform/app_build.dart';
import '../../../../core/platform/share_file.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/share_or_copy.dart';
import '../../../favourites/domain/entities/favourite.dart';
import '../../../favourites/presentation/cubit/favourites_cubit.dart';
import '../../../favourites/presentation/cubit/favourites_state.dart';
import '../../domain/entities/listing.dart';
import '../listing_detail_text.dart';
import '../listing_report_pdf.dart' deferred as report_pdf;
import '../listing_report_text.dart';
import '../offer_context.dart';

/// "Relatório do anúncio" (16.8, N.127): the ad's whole analysis as a PDF,
/// sent through the share sheet (downloaded where the browser can't share
/// files) to a mechanic or to whoever goes to see the bike, or as text with
/// the app's link. The offer's figures are asked for as the card is built
/// (the same answer as "Quanto oferecer") and the PDF is made from them
/// at once, again when the visit's checklist or the language changes, so
/// the tap opens the share sheet straight away, as Safari requires.
class const ListingReportCard({required final Listing listing, super.key})
    extends StatefulWidget {
  @override
  State<ListingReportCard> createState() => _ListingReportCardState();
}

class _ListingReportCardState extends State<ListingReportCard> {
  late final Future<OfferContext> _context = offerContextOf(widget.listing);
  OfferContext? _loaded;
  late final StreamSubscription<FavouritesState> _favourites;
  Map<String, ChecklistEntry> _checklist = const {};
  AppLanguage? _language;

  /// The PDF for [_loaded], [_checklist] and [_language], once made.
  Future<Uint8List>? _pdf;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    final favourites = getIt<FavouritesCubit>();
    _checklist = _checklistIn(favourites.state);
    _favourites = favourites.stream.listen((state) {
      final checklist = _checklistIn(state);
      if (identical(checklist, _checklist)) return;
      _checklist = checklist;
      _makePdf();
    });
    _context.then((value) {
      if (!mounted) return;
      setState(() => _loaded = value);
      _makePdf();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = context.language;
    if (language == _language) return;
    _language = language;
    _makePdf();
  }

  @override
  void dispose() {
    unawaited(_favourites.cancel());
    super.dispose();
  }

  Map<String, ChecklistEntry> _checklistIn(FavouritesState state) =>
      state.favouriteOf(widget.listing.id)?.checklist ?? const {};

  ListingReport _report(AppLanguage language) {
    final (market, cheaper) = _loaded ?? (null, const <Listing>[]);
    return listingReportOf(
      widget.listing,
      today: DateTime.now(),
      market: market,
      cheaper: cheaper,
      checklist: _checklist,
      language: language,
    );
  }

  /// Makes the PDF ahead of the tap, once the offer's figures are in.
  void _makePdf() {
    final language = _language;
    if (_loaded == null || language == null) return;
    _pdfBytes = null;
    final pdf = _pdf = _buildPdf(language);
    unawaited(
      pdf.then(
        (bytes) {
          if (identical(pdf, _pdf)) _pdfBytes = bytes;
        },
        // A PDF that can't be made is shared as text on the tap.
        onError: (Object _) {},
      ),
    );
  }

  Future<Uint8List> _buildPdf(AppLanguage language) async {
    await report_pdf.loadLibrary();
    final fonts = await Future.wait([
      for (final file in const [
        'Barlow-Regular',
        'Barlow-Medium',
        'Barlow-SemiBold',
        'BarlowSemiCondensed-Bold',
      ])
        rootBundle.load('assets/fonts/$file.ttf'),
    ]);
    final scheme = AppTheme.light.colorScheme;
    return await report_pdf.listingReportPdf(
      _report(language),
      fonts: report_pdf.ReportFonts(
        regular: fonts[0],
        medium: fonts[1],
        semiBold: fonts[2],
        display: fonts[3],
      ),
      palette: report_pdf.ReportPalette(
        primary: scheme.primary.toARGB32(),
        ink: scheme.onSurface.toARGB32(),
        muted: scheme.onSurfaceVariant.toARGB32(),
        hairline: scheme.outlineVariant.toARGB32(),
        panel: scheme.surfaceContainer.toARGB32(),
        positive: AppColors.light.positive.toARGB32(),
        negative: AppColors.light.negative.toARGB32(),
        onBand: AppColors.onPhoto.toARGB32(),
      ),
      appUrl: listingLink(webOrigin, widget.listing.id),
      appName: appName,
    );
  }

  Future<void> _sharePdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.strings;
    final language = context.language;
    var bytes = _pdfBytes;
    if (bytes == null) {
      // Not made yet (the offer's figures still on their way): made now.
      // Safari may then no longer open the sheet, and the file downloads.
      try {
        bytes = await (_pdf ?? _buildPdf(language));
      } on Object {
        bytes = null;
      }
    }
    if (!mounted) return;
    final outcome = bytes == null
        ? FileShareOutcome.unavailable
        : await shareFile(
            bytes: bytes,
            name: reportFileName(widget.listing, language: language),
            type: 'application/pdf',
            title: strings.reportTitle(bike: widget.listing.nameAndYear),
          );
    if (!mounted) return;
    switch (outcome) {
      case .shared:
        break;
      case .downloaded:
        messenger.showSnackBar(
          SnackBar(content: Text(strings.reportDownloaded)),
        );
      case .unavailable:
        _shareText();
    }
  }

  void _shareText() {
    final listing = widget.listing;
    final (market, cheaper) = _loaded ?? (null, const <Listing>[]);
    shareOrCopy(
      ScaffoldMessenger.of(context),
      title: context.strings.reportTitle(bike: listing.nameAndYear),
      text: listingReportText(
        listing,
        today: DateTime.now(),
        market: market,
        cheaper: cheaper,
        checklist: _checklist,
        language: context.language,
      ),
      url: listingLink(webOrigin, listing.id),
      language: context.language,
    );
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    title: context.strings.listingReport,
    children: [
      Text(context.strings.listingReportBody),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: _sharePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(context.strings.shareReport),
          ),
          TextButton.icon(
            onPressed: _shareText,
            icon: const Icon(Icons.notes),
            label: Text(context.strings.shareReportText),
          ),
        ],
      ),
    ],
  );
}
