import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'listing_report.dart';
import 'score_breakdown.dart';

/// The app's own fonts for the PDF (assets/fonts): Barlow for text,
/// Barlow Semi Condensed Bold for the bike, prices and scores.
class const ReportFonts({
  required final ByteData regular,
  required final ByteData medium,
  required final ByteData semiBold,
  required final ByteData display,
});

/// The PDF's colours (ARGB), from the app's light theme: paper is white.
class const ReportPalette({
  required final int primary,
  required final int ink,
  required final int muted,
  required final int hairline,
  required final int panel,
  required final int positive,
  required final int negative,
  required final int onBand,
});

/// The ad's report as an A4 PDF (N.127), laid out as the ad's page: the
/// bike, its price and specs, the Deal Score and Risk Score tiles with
/// their bands, then each section under its title, the offer's steps as
/// figures, the Deal Score's sums and the links. Every line is its own
/// block, so a long report flows onto the next page between them.
/// [appUrl] is the ad's page in the app.
Future<Uint8List> listingReportPdf(
  ListingReport report, {
  required ReportFonts fonts,
  required ReportPalette palette,
  required String appUrl,
  required String appName,
}) {
  final styles = _Styles(fonts, palette);
  final document = pw.Document(
    title: report.title,
    creator: appName,
    producer: appName,
  );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 40, 44, 36),
      theme: pw.ThemeData.withFont(base: styles.regular, bold: styles.semiBold),
      footer: (context) => _footer(context, styles, appName),
      build: (context) => [
        ..._hero(report, styles),
        pw.SizedBox(height: 18),
        _scoreTiles(report, styles),
        if (report.deal != null && report.reasons.isNotEmpty) ...[
          _sectionTitle(report.reasonsTitle, styles),
          for (final line in report.reasons) _toned(line, styles),
        ],
        for (final section in report.sections) ..._section(section, styles),
        if (report.breakdown case final breakdown?)
          ..._breakdown(report.breakdownTitle, breakdown, styles),
        ..._closing(report, styles, appUrl),
      ],
    ),
  );
  return document.save();
}

class _Styles {
  _Styles(ReportFonts fonts, this.palette)
    : regular = pw.Font.ttf(fonts.regular),
      medium = pw.Font.ttf(fonts.medium),
      semiBold = pw.Font.ttf(fonts.semiBold),
      display = pw.Font.ttf(fonts.display);

  final ReportPalette palette;
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font semiBold;
  final pw.Font display;

  PdfColor get primary => PdfColor.fromInt(palette.primary);
  PdfColor get ink => PdfColor.fromInt(palette.ink);
  PdfColor get muted => PdfColor.fromInt(palette.muted);
  PdfColor get hairline => PdfColor.fromInt(palette.hairline);
  PdfColor get panel => PdfColor.fromInt(palette.panel);

  PdfColor tone(ReportTone? tone) => switch (tone) {
    ReportTone.positive => PdfColor.fromInt(palette.positive),
    ReportTone.negative => PdfColor.fromInt(palette.negative),
    _ => muted,
  };

  pw.TextStyle get body =>
      pw.TextStyle(font: regular, fontSize: 10, color: ink, lineSpacing: 2);

  pw.TextStyle get small => pw.TextStyle(
    font: regular,
    fontSize: 8.5,
    color: muted,
    lineSpacing: 1.5,
  );

  /// Small capitals over a figure or a part ("PREÇO ANUNCIADO").
  pw.TextStyle label({PdfColor? colour}) => pw.TextStyle(
    font: semiBold,
    fontSize: 7.5,
    color: colour ?? muted,
    letterSpacing: 0.9,
  );

  pw.TextStyle figure(double size, {PdfColor? colour}) =>
      pw.TextStyle(font: display, fontSize: size, color: colour ?? ink);
}

List<pw.Widget> _hero(ListingReport report, _Styles styles) => [
  pw.Text(
    report.eyebrow.toUpperCase(),
    style: styles.label(colour: styles.primary),
  ),
  pw.SizedBox(height: 6),
  pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(report.bike, style: styles.figure(28)),
            if (report.specs.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final spec in report.specs) _chip(spec, styles),
                ],
              ),
            ],
          ],
        ),
      ),
      pw.SizedBox(width: 16),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(report.priceName.toUpperCase(), style: styles.label()),
          pw.SizedBox(height: 2),
          pw.Text(report.price, style: styles.figure(24)),
        ],
      ),
    ],
  ),
  if (report.about.isNotEmpty) ...[
    pw.SizedBox(height: 10),
    pw.Text(
      report.about.join('  ·  '),
      style: styles.body.copyWith(color: styles.muted),
    ),
  ],
  pw.SizedBox(height: 4),
  pw.Text(report.madeOn, style: styles.small),
];

pw.Widget _chip(String text, _Styles styles) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: pw.BoxDecoration(
    color: styles.panel,
    borderRadius: pw.BorderRadius.circular(4),
  ),
  child: pw.Text(
    text,
    style: pw.TextStyle(font: styles.medium, fontSize: 9, color: styles.ink),
  ),
);

pw.Widget _scoreTiles(ListingReport report, _Styles styles) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Expanded(
      child: report.deal == null
          ? _emptyTile('Deal Score', report.notScoredShort, styles)
          : _scoreTile(report.deal!, styles),
    ),
    pw.SizedBox(width: 12),
    pw.Expanded(
      child: report.risk == null
          ? _emptyTile('Risk Score', report.notScoredShort, styles)
          : _scoreTile(report.risk!, styles),
    ),
  ],
);

pw.BoxDecoration _tileBox(_Styles styles) => pw.BoxDecoration(
  border: pw.Border.all(color: styles.hairline, width: 0.8),
  borderRadius: pw.BorderRadius.circular(8),
);

pw.Widget _scoreTile(ReportScore score, _Styles styles) => pw.Container(
  padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 12),
  decoration: _tileBox(styles),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(score.name.toUpperCase(), style: styles.label()),
      pw.SizedBox(height: 2),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('${score.figure}', style: styles.figure(34)),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 3, bottom: 6),
            child: pw.Text(
              '/ 100',
              style: pw.TextStyle(
                font: styles.medium,
                fontSize: 10,
                color: styles.muted,
              ),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 2),
      _scoreBar(score, styles),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(score.colour),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          score.band.toUpperCase(),
          style: styles.label(colour: PdfColor.fromInt(styles.palette.onBand)),
        ),
      ),
    ],
  ),
);

/// The figure as a bar out of 100, in the band's colour.
pw.Widget _scoreBar(ReportScore score, _Styles styles) => pw.Container(
  height: 4,
  decoration: pw.BoxDecoration(
    color: styles.panel,
    borderRadius: pw.BorderRadius.circular(2),
  ),
  child: pw.Row(
    children: [
      if (score.figure > 0)
        pw.Expanded(
          flex: score.figure.clamp(1, 100),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(score.colour),
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
        ),
      if (score.figure < 100)
        pw.Expanded(
          flex: 100 - score.figure.clamp(0, 99),
          child: pw.SizedBox(),
        ),
    ],
  ),
);

pw.Widget _emptyTile(String name, String text, _Styles styles) => pw.Container(
  padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 12),
  decoration: _tileBox(styles),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(name.toUpperCase(), style: styles.label()),
      pw.SizedBox(height: 2),
      pw.Text('–', style: styles.figure(34, colour: styles.muted)),
      pw.SizedBox(height: 4),
      pw.Text(text, style: styles.small),
    ],
  ),
);

/// A section's title: an orange bar, the title, a hairline under it.
pw.Widget _sectionTitle(String title, _Styles styles) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 20, bottom: 6),
  padding: const pw.EdgeInsets.only(bottom: 5),
  decoration: pw.BoxDecoration(
    border: pw.Border(
      bottom: pw.BorderSide(color: styles.hairline, width: 0.8),
    ),
  ),
  child: pw.Row(
    children: [
      pw.Container(width: 3, height: 13, color: styles.primary),
      pw.SizedBox(width: 7),
      pw.Expanded(child: pw.Text(title, style: styles.figure(14))),
    ],
  ),
);

/// An item of a list: a dot in its tone's colour, then the text.
pw.Widget _toned(ReportLine line, _Styles styles) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 6,
        height: 6,
        margin: const pw.EdgeInsets.only(top: 3.5, right: 8),
        decoration: pw.BoxDecoration(
          color: styles.tone(line.tone),
          shape: pw.BoxShape.circle,
        ),
      ),
      pw.Expanded(child: pw.Text(line.text, style: styles.body)),
    ],
  ),
);

List<pw.Widget> _section(ReportSection section, _Styles styles) {
  final widgets = <pw.Widget>[_sectionTitle(section.title, styles)];
  final lines = section.lines;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.value != null) {
      // The offer's steps side by side, as figures.
      final steps = [
        for (var j = i; j < lines.length && lines[j].value != null; j++)
          lines[j],
      ];
      widgets.add(_steps(steps, styles));
      i += steps.length - 1;
    } else if (line.heading) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 3),
          child: pw.Text(line.text.toUpperCase(), style: styles.label()),
        ),
      );
    } else if (line.tone != null) {
      widgets.add(_toned(line, styles));
    } else {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Text(line.text, style: styles.body),
        ),
      );
    }
  }
  return widgets;
}

pw.Widget _steps(List<ReportLine> steps, _Styles styles) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final (index, step) in steps.indexed) ...[
        if (index > 0) pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 8),
            decoration: pw.BoxDecoration(
              color: styles.panel,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(step.text, style: styles.small),
                pw.SizedBox(height: 2),
                pw.Text(
                  step.value!,
                  style: styles.figure(
                    16,
                    colour: index == steps.length - 1
                        ? styles.ink
                        : styles.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  ),
);

List<pw.Widget> _breakdown(
  String title,
  ScoreBreakdown breakdown,
  _Styles styles,
) => [
  _sectionTitle(title, styles),
  for (final row in breakdown.rows) _breakdownRow(row, styles),
  pw.Container(
    margin: const pw.EdgeInsets.only(top: 6, bottom: 2),
    height: 0.8,
    color: styles.hairline,
  ),
  for (final total in breakdown.totals) _totalRow(total, styles),
];

pw.Widget _breakdownRow(ScoreBreakdownRow row, _Styles styles) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 5),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Text(
              row.label,
              style: pw.TextStyle(
                font: styles.semiBold,
                fontSize: 10.5,
                color: row.counted ? styles.ink : styles.muted,
              ),
            ),
          ),
          if (row.share case final share?)
            pw.Text(
              row.points == null ? share : '$share · ${row.points}',
              style: styles.small,
            ),
          if (row.score case final score?) ...[
            pw.SizedBox(width: 10),
            pw.Text(score, style: styles.figure(11.5)),
          ],
        ],
      ),
      for (final detail in row.details)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(detail, style: styles.small),
        ),
    ],
  ),
);

pw.Widget _totalRow(ScoreBreakdownTotal total, _Styles styles) {
  final style = total.isResult
      ? styles.figure(13)
      : styles.body.copyWith(color: styles.muted);
  return pw.Padding(
    padding: pw.EdgeInsets.only(top: total.isResult ? 5 : 2, bottom: 2),
    child: pw.Row(
      children: [
        pw.Expanded(child: pw.Text(total.label, style: style)),
        pw.SizedBox(width: 12),
        pw.Text(total.value, style: style),
      ],
    ),
  );
}

List<pw.Widget> _closing(ListingReport report, _Styles styles, String appUrl) {
  pw.Widget link(String label, String url) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.UrlLink(
      destination: url,
      child: pw.RichText(
        text: pw.TextSpan(
          style: styles.small,
          children: [
            pw.TextSpan(text: '$label '),
            pw.TextSpan(
              text: url,
              style: pw.TextStyle(
                color: styles.primary,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  final adLine = report.adLine;
  final adUrl = report.adUrl;
  return [
    pw.Container(
      margin: const pw.EdgeInsets.only(top: 22),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: styles.panel,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              report.note,
              style: styles.small.copyWith(color: styles.ink),
            ),
          ),
        ],
      ),
    ),
    // "Anúncio original: <url>": the words, then the address as a link.
    if (adLine != null && adUrl != null)
      link(adLine.replaceFirst(adUrl, '').trim(), adUrl),
    link(report.onApp, appUrl),
  ];
}

pw.Widget _footer(pw.Context context, _Styles styles, String appName) =>
    pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: styles.hairline, width: 0.8),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(appName, style: styles.label())),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: styles.label(),
          ),
        ],
      ),
    );
