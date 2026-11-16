"""Tests for tool/tax_tables.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import os
import unittest

from tax_tables import (FIRST_CHARGED_CC, IMPORT_COST, OWNERSHIP_COST, SCHEMA, TableNotFound,
                        compare, dart_bands, dart_year, differences, euros, parse_isv, parse_iuc,
                        sql_bands, summary)

# pdftotext -layout of SFP-Taxas-2026.pdf, the two tables' pages (trimmed).
PDF_2026 = """\
TABELA C

Estabelece as taxas de imposto, aplicáveis aos motociclos, triciclos e quadriciclos.

Taxas


                                                       TAXA FIXA
               ESCALÃO DE CILINDRADA (CM3)
                                                           (€)
             De 120 a 250                                 73,78
             De 251 a 350                                 91,63
             De 351 a 500                                122,57
             De 501 a 750                                184,45

             Mais de 750                                 245,14
                                                             SISTEMA FISCAL PORTUGUÊS
                                                             TAXAS APLICÁVEIS 2026 - ISV
VEÍCULOS DA CATEGORIA E

Nos termos do art.º 13.º, do CIUC, as taxas aplicáveis aos veículos da categoria E,
são as seguintes:


                                               TAXA ANUAL
 ESCALÃO DE CILINDRADA          (SEGUNDO O ANO DA MATRÍCULA DO VEÍCULO) (€)
         (CM3)
                                 POSTERIOR A 1996            ENTRE 1992 E 1996

 De 120 até 250                         6,19                        0,00
 Mais de 250 até 350                    8,76                        6,19
 Mais de 350 até 500                   21,18                       12,53
 Mais de 500 até 750                   63,62                       37,47
 Mais de 750                           138,15                      67,76
"""

ISV_2026 = [(250, 73.78), (350, 91.63), (500, 122.57), (750, 184.45), (None, 245.14)]
IUC_2026 = [(250, 6.19), (350, 8.76), (500, 21.18), (750, 63.62), (None, 138.15)]

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def read(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as source:
        return source.read()


class ParseTest(unittest.TestCase):
    def test_euros_reads_portuguese_amounts(self):
        self.assertEqual(euros("73,78"), 73.78)
        self.assertEqual(euros("1.245,14"), 1245.14)

    def test_isv_tabela_c(self):
        self.assertEqual(parse_isv(PDF_2026), (120, ISV_2026))

    def test_iuc_categoria_e_takes_the_after_1996_column(self):
        self.assertEqual(parse_iuc(PDF_2026), (120, IUC_2026))

    def test_a_changed_layout_is_not_found(self):
        with self.assertRaises(TableNotFound):
            parse_isv(PDF_2026.replace("TABELA C", "TABELA X"))
        with self.assertRaises(TableNotFound):
            parse_iuc(PDF_2026.replace("Mais de 750      ", "Acima de 750     "))


class RepositoryTest(unittest.TestCase):
    """The repository's own copies are read, and agree with 2026's PDF."""

    def test_app_and_database_bands(self):
        self.assertEqual(dart_bands(read(IMPORT_COST), "isvBands"), ISV_2026)
        self.assertEqual(dart_bands(read(OWNERSHIP_COST), "iucBands"), IUC_2026)
        self.assertEqual(sql_bands(read(SCHEMA)), ISV_2026)
        self.assertGreaterEqual(dart_year(read(IMPORT_COST), "isvTableYear"), 2026)

    def test_no_difference_with_2026(self):
        self.assertEqual(differences(PDF_2026, 2026, read(IMPORT_COST),
                                     read(OWNERSHIP_COST), read(SCHEMA)), [])


DART = """
const isvTableYear = 2026;
const isvBands = <({int? maxCc, double euros})>[
  (maxCc: 119, euros: 0),
  (maxCc: 250, euros: 73.78),
  (maxCc: 350, euros: 91.63),
  (maxCc: 500, euros: 122.57),
  (maxCc: 750, euros: 184.45),
  (maxCc: null, euros: 245.14),
];
const iucTableYear = 2026;
const iucBands = <({int? maxCc, double euros})>[
  (maxCc: 119, euros: 0),
  (maxCc: 250, euros: 6.19),
  (maxCc: 350, euros: 8.76),
  (maxCc: 500, euros: 21.18),
  (maxCc: 750, euros: 63.62),
  (maxCc: null, euros: 138.15),
];
"""

SQL = """
CREATE FUNCTION public.motorcycle_isv(p_engine_cc integer) RETURNS numeric
    AS $$
  select case
    when p_engine_cc is null then 245.14
    when p_engine_cc <= 119 then 0
    when p_engine_cc <= 250 then 73.78
    when p_engine_cc <= 350 then 91.63
    when p_engine_cc <= 500 then 122.57
    when p_engine_cc <= 750 then 184.45
    else 245.14
  end
$$;
"""


class DifferencesTest(unittest.TestCase):
    def test_a_new_amount_names_the_band_and_every_copy(self):
        pdf = PDF_2026.replace("184,45", "190,00").replace("138,15", "140,00")
        self.assertEqual(differences(pdf, 2026, DART, DART, SQL), [
            "isvBands até 750 cc: 184.45 € -> 190.00 €",
            "motorcycle_isv até 750 cc: 184.45 € -> 190.00 €",
            "iucBands mais: 138.15 € -> 140.00 €",
        ])

    def test_new_bands(self):
        self.assertEqual(compare("isvBands", [(250, 70.0), (None, 200.0)], ISV_2026),
                         ["isvBands: escalões novos (até 250 cc: 70.00, mais: 200.00)"])

    def test_a_new_first_charged_size(self):
        pdf = PDF_2026.replace("De 120 a 250", "De 126 a 250")
        self.assertIn("isvBands: a tabela começa agora em 126 cc",
                      differences(pdf, 2026, DART, DART, SQL))
        self.assertEqual(FIRST_CHARGED_CC, 120)

    def test_the_same_tables_a_year_on_raise_the_years(self):
        self.assertEqual(differences(PDF_2026, 2027, DART, DART, SQL),
                         ["isvTableYear ainda é 2026", "iucTableYear ainda é 2026"])

    def test_an_unreadable_table_is_a_difference(self):
        found = differences(PDF_2026.replace("TABELA C", "TABELA X"), 2026, DART, DART, SQL)
        self.assertEqual(found, ["Não foi possível ler ISV Tabela C do PDF de 2026"])

    def test_summary(self):
        self.assertIn("ainda não foi publicado", summary(2027, [], published=False))
        self.assertIn("iguais", summary(2026, []))
        self.assertIn("- isvTableYear ainda é 2026\n", summary(2027, ["isvTableYear ainda é 2026"]))


if __name__ == "__main__":
    unittest.main()
