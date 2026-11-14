import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/collapsible_section.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../favourites/presentation/cubit/favourites_cubit.dart';
import '../../../favourites/presentation/cubit/favourites_state.dart';
import '../../../listings/domain/entities/listing.dart';
import '../../../listings/presentation/negotiation_text.dart';
import '../../../listings/presentation/offer_text.dart';
import '../financing.dart';
import '../financing_text.dart';
import '../import_cost.dart';
import 'calculator_field.dart';

/// "E se pagar a prestações?" (N.69): the listing's price (or the one
/// agreed) with a deposit, a term and the TAEG of a quote gives the
/// instalment, the total paid and the interest, and the same loan at the
/// most to pay of "Quanto oferecer" (after the visit's repairs). One
/// closed line until asked for; worked out as the person types, nothing
/// is saved. Only for a listing with a price.
class const FinancingCard({required final Listing listing, super.key})
    extends StatefulWidget {
  @override
  State<FinancingCard> createState() => _FinancingCardState();
}

class _FinancingCardState extends State<FinancingCard> {
  late final _price = TextEditingController(
    text: widget.listing.askingPrice?.round().toString() ?? '',
  );
  final _deposit = TextEditingController();
  final _apr = TextEditingController();
  var _months = defaultFinancingMonths;

  @override
  void dispose() {
    _price.dispose();
    _deposit.dispose();
    _apr.dispose();
    super.dispose();
  }

  /// The loan once the price and the TAEG are typed; null before.
  FinancingCost? _cost() {
    final price = parseWholeAmount(_price.text);
    final apr = parseRate(_apr.text);
    if (price == null || price == 0 || apr == null) return null;
    return financingCost(
      price: price.toDouble(),
      deposit: (parseWholeAmount(_deposit.text) ?? 0).toDouble(),
      months: _months,
      apr: apr,
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required String suffix,
    String? helper,
    bool decimal = false,
  }) => CalculatorField(
    controller: controller,
    label: label,
    suffix: suffix,
    helper: helper,
    decimal: decimal,
    onChanged: () => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    if (listing.askingPrice == null) return const SizedBox.shrink();
    return BlocBuilder<FavouritesCubit, FavouritesState>(
      bloc: getIt<FavouritesCubit>(),
      builder: (context, favourites) {
        final offer = suggestOffer(listing, language: context.language);
        final ceiling = offer == null
            ? null
            : afterVisit(
                offer,
                listingVisitFindings(
                  listing,
                  favourites.favouriteOf(listing.id)?.checklist ?? const {},
                  language: context.language,
                ),
                language: context.language,
              ).ceiling;
        return _card(context, ceiling);
      },
    );
  }

  Widget _card(BuildContext context, double? ceiling) {
    final strings = context.strings;
    final cost = _cost();
    return FoldedCard(
      title: strings.financingTitle,
      summary: strings.financingFolded,
      footnote: strings.financingNote,
      children: [
        Text(strings.financingIntro),
        const SizedBox(height: 16),
        _field(
          _price,
          strings.financingPrice,
          suffix: '€',
          helper: strings.financingPriceHint,
        ),
        _field(_deposit, strings.financingDeposit, suffix: '€'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<int>(
            initialValue: _months,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: strings.financingMonths,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final months in financingMonths)
                DropdownMenuItem(
                  value: months,
                  child: Text(strings.financingMonthsOption(months: months)),
                ),
            ],
            onChanged: (months) {
              if (months != null) setState(() => _months = months);
            },
          ),
        ),
        _field(
          _apr,
          strings.financingApr,
          suffix: '%',
          helper: strings.financingAprHint,
          decimal: true,
        ),
        if (cost != null)
          for (final line in financingLines(
            cost,
            offer: ceiling,
            language: context.language,
          ))
            BulletLine(line, icon: Icons.payments_outlined),
      ],
    );
  }
}
