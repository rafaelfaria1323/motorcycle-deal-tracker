/// Where a bike can be bought abroad, with the usual price of bringing one
/// to Portugal by a transport company (rules of thumb, 2026; the owner
/// can enter a quote instead).
enum ImportCountry {
  spain(transport: 350),
  france(transport: 550),
  germany(transport: 700);

  const ImportCountry({required this.transport});

  final double transport;
}

/// ISV, Tabela C (motociclos, triciclos e quadriciclos), euros by engine
/// size (Código do ISV, art. 7; the 2024 amounts, kept in 2025 and 2026);
/// under 120 cc the table charges nothing. The State Budget can change
/// them every January: check and update [isvTableYear] with them, as
/// `iucBands`.
const isvTableYear = 2026;
const isvBands = <({int? maxCc, double euros})>[
  (maxCc: 119, euros: 0),
  (maxCc: 250, euros: 73.78),
  (maxCc: 350, euros: 91.63),
  (maxCc: 500, euros: 122.57),
  (maxCc: 750, euros: 184.45),
  (maxCc: null, euros: 245.14),
];

/// Legalisation in Portugal, rules of thumb (2026): the inspection for a
/// Portuguese registration (category B), the IMT's registration and the
/// car registry, and the plates. The customs declaration (DAV) is free.
const importInspection = 95.0;
const importRegistration = 100.0;
const importPlates = 30.0;

/// A bike up to 6 months old or this far driven counts as new for VAT:
/// the VAT is then paid in Portugal (23 %), whoever sold it.
const newForVatKm = 6000;

/// The ISV of a bike of [engineCc]. Shown without the reduction for used
/// vehicles (art. 11), not confirmed for motorcycles, so it is the most
/// it can be (under 250 € anyway).
double isvFor(int engineCc) =>
    isvBands.firstWhere((b) => b.maxCc == null || engineCc <= b.maxCc!).euros;

/// The cost of a bike bought abroad, on the road in Portugal.
typedef ImportCost = ({
  double price,
  double isv,
  double legalisation,
  double transport,
  double total,
});

/// [price] there plus the ISV, the legalisation and the transport
/// ([transport] when the owner has a quote, else the country's usual).
ImportCost importCost({
  required double price,
  required int engineCc,
  required ImportCountry country,
  double? transport,
}) {
  final isv = isvFor(engineCc);
  const legalisation = importInspection + importRegistration + importPlates;
  final carriage = transport ?? country.transport;
  return (
    price: price,
    isv: isv,
    legalisation: legalisation,
    transport: carriage,
    total: price + isv + legalisation + carriage,
  );
}

/// Whether the bike may count as new for VAT ([newForVatKm] or less, or
/// the mileage unknown, and registered this year or the last: the month
/// isn't asked, so the last year's bikes are only possibly new).
bool mayBeNewForVat({required int year, int? mileage, required DateTime now}) =>
    year >= now.year - 1 && (mileage == null || mileage <= newForVatKm);

/// A whole amount as typed ("5 400", "5.400 €"); null when it isn't one.
int? parseWholeAmount(String text) {
  final digits = text.trim().replaceAll(RegExp(r'[\s.€]'), '');
  return RegExp(r'^\d+$').hasMatch(digits) ? int.parse(digits) : null;
}
