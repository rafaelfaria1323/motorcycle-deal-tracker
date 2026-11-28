import 'score_breakdown.dart';

/// Whether a line of the report is good news, bad news or neither.
enum ReportTone { positive, negative, neutral }

/// A line of the report (16.8, N.127). With a [tone] it is an item of a
/// list ("+ ", "− ", "· " in the text, a coloured mark in the PDF); with
/// a [value] a label and its figure ("· Abertura: 6 450 €"); a [heading]
/// opens a list inside a section ("Argumentos").
class const ReportLine(
  final String text, {
  final ReportTone? tone,
  final String? value,
  final bool heading = false,
});

/// A part of the report with its title ("Mercado", "Quanto oferecer").
class const ReportSection(final String title, final List<ReportLine> lines);

/// The Deal Score or the Risk Score: its [figure] out of 100, its band's
/// name, the sentence the text gives it and the band's colour (ARGB).
class const ReportScore({
  required final String name,
  required final int figure,
  required final String band,
  required final String line,
  required final int colour,
});

/// The ad's report in parts (N.127): what [listingReportText] writes as
/// plain text and the PDF lays out. Sections without anything to say are
/// left out already.
class const ListingReport({
  /// "Relatório: Yamaha MT-07 · 2021".
  required final String title,

  /// "Feito em 28/11/2026 no Motorcycle Deal Tracker."
  required final String madeOn,

  /// The section heading over the bike's name ("Relatório do anúncio").
  required final String eyebrow,

  /// "Yamaha MT-07", and its year when known.
  required final String bike,
  required final int? year,

  /// "Preço anunciado" and the price (or "Preço por consultar").
  required final String priceName,
  required final String price,

  /// Year, km and engine size.
  required final List<String> specs,

  /// The seller, the place and a gone ad's status.
  required final List<String> about,
  required final ReportScore? deal,
  required final ReportScore? risk,

  /// The text's line when there is no [deal], and the PDF's tile's.
  required final String notScored,
  required final String notScoredShort,

  /// "Porquê esta pontuação" and the Deal Score's reasons.
  required final String reasonsTitle,
  required final List<ReportLine> reasons,

  /// Market, offer, visit and recalls, in that order.
  required final List<ReportSection> sections,

  /// "Cálculo da pontuação" and the Deal Score's sums (PDF only).
  required final String breakdownTitle,
  required final ScoreBreakdown? breakdown,

  /// That the figures come from asking prices.
  required final String note,

  /// "Anúncio original: `url`", and the address alone.
  required final String? adLine,
  required final String? adUrl,

  /// "No Motorcycle Deal Tracker:", which the app's link follows.
  required final String onApp,
});
