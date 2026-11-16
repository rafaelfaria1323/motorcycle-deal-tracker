"""The yearly tax tables against the app's and the database's copies (N.114).

The Tax Authority (AT) publishes every year's rates in one PDF, "Sistema
Fiscal Português - Taxas aplicáveis" (SFP-Taxas-<year>.pdf, free, no key).
This reads the two tables the app uses from its text (pdftotext -layout):
ISV Tabela C (motorcycles) and IUC category E (after 1996), and compares
them with `isvBands` / `isvTableYear` (import_cost.dart), `iucBands` /
`iucTableYear` (ownership_cost.dart) and `motorcycle_isv` (schema.sql).
No AI: fixed patterns; a table it can't read is reported as a difference,
since the layout changed and a person has to look.

    python3 tool/tax_tables.py [--year 2027] [--pdf FILE] [--json-out FILE]

A year whose PDF isn't published yet (404) is no difference. The result is
written to the step summary ($GITHUB_STEP_SUMMARY) and, with --json-out, as
{"year": ..., "differences": [...]} for the admins' notice (tax-tables.yml).
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

PDF_URL = ("https://info.portaldasfinancas.gov.pt/pt/apoio_contribuinte/"
           "Folhetos_informativos/Documents/SFP-Taxas-{year}.pdf")
IMPORT_COST = "app/lib/features/valuation/presentation/import_cost.dart"
OWNERSHIP_COST = "app/lib/features/valuation/presentation/ownership_cost.dart"
SCHEMA = "supabase/schema.sql"
# The tables start charging at this engine size; below it, nothing.
FIRST_CHARGED_CC = 120
# Lines of text a table is looked for in, after its heading.
TABLE_SPAN = 40

AMOUNT = r"(\d{1,3}(?:\.\d{3})*,\d{2})"


class TableNotFound(Exception):
    pass


def euros(text):
    """'1.245,14' -> 1245.14"""
    return float(text.replace(".", "").replace(",", "."))


def _lines_after(text, heading):
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip().upper() == heading:
            return lines[i + 1:i + 1 + TABLE_SPAN]
    raise TableNotFound(heading)


def _bands(lines, rows):
    """Bands [(max_cc or None, euros)] from the first rows matching `rows`
    (each a pattern giving the lower bound, the upper bound or None, and the
    amount), in order, up to the open-ended one."""
    bands = []
    lower = None
    for line in lines:
        for pattern in rows:
            match = re.match(pattern, line.strip())
            if not match:
                continue
            low, high, amount = match.group("low"), match.group("high"), match.group("amount")
            if lower is None:
                lower = int(low)
            bands.append((int(high) if high else None, euros(amount)))
            break
        if bands and bands[-1][0] is None:
            return lower, bands
    raise TableNotFound("rows")


def parse_isv(text):
    """ISV Tabela C: (first charged cc, bands)."""
    try:
        return _bands(_lines_after(text, "TABELA C"), [
            r"De (?P<low>\d+) a (?P<high>\d+)\s+" + AMOUNT.replace("(", "(?P<amount>", 1) + r"$",
            r"Mais de (?P<low>\d+)(?P<high>)\s+" + AMOUNT.replace("(", "(?P<amount>", 1) + r"$",
        ])
    except TableNotFound as error:
        raise TableNotFound("ISV Tabela C") from error


def parse_iuc(text):
    """IUC category E, the first column (registered after 1996)."""
    amount = AMOUNT.replace("(", "(?P<amount>", 1)
    try:
        return _bands(_lines_after(text, "VEÍCULOS DA CATEGORIA E"), [
            r"De (?P<low>\d+) até (?P<high>\d+)\s+" + amount + r"\s",
            r"Mais de (?P<low>\d+) até (?P<high>\d+)\s+" + amount + r"\s",
            r"Mais de (?P<low>\d+)(?P<high>)\s+" + amount + r"\s",
        ])
    except TableNotFound as error:
        raise TableNotFound("IUC categoria E") from error


def dart_bands(source, name):
    """The charged bands of `const name = <...>[ (maxCc: .., euros: ..), ... ];`
    (the free one under FIRST_CHARGED_CC left out)."""
    block = re.search(r"const " + name + r" = <[^>]*>\[(.*?)\];", source, re.S)
    if not block:
        raise TableNotFound(name)
    bands = [(None if cc == "null" else int(cc), float(value))
             for cc, value in re.findall(r"\(maxCc: (\d+|null), euros: ([\d.]+)\)", block.group(1))]
    return [band for band in bands if band[0] is None or band[0] >= FIRST_CHARGED_CC]


def dart_year(source, name):
    match = re.search(r"const " + name + r" = (\d{4});", source)
    if not match:
        raise TableNotFound(name)
    return int(match.group(1))


def sql_bands(schema):
    """motorcycle_isv's charged bands, from schema.sql."""
    body = re.search(r"FUNCTION public\.motorcycle_isv\(.*?\$\$(.*?)\$\$", schema, re.S)
    if not body:
        raise TableNotFound("motorcycle_isv")
    bands = [(int(cc), float(value)) for cc, value in
             re.findall(r"when p_engine_cc <= (\d+) then ([\d.]+)", body.group(1))]
    other = re.search(r"else ([\d.]+)", body.group(1))
    if not other:
        raise TableNotFound("motorcycle_isv")
    bands.append((None, float(other.group(1))))
    return [band for band in bands if band[0] is None or band[0] >= FIRST_CHARGED_CC]


def _label(band):
    return "mais" if band[0] is None else f"até {band[0]} cc"


def compare(name, official, ours):
    """Lines saying how `ours` differs from the official bands."""
    if official == ours:
        return []
    if [band[0] for band in official] != [band[0] for band in ours]:
        shown = ", ".join(f"{_label(b)}: {b[1]:.2f}" for b in official)
        return [f"{name}: escalões novos ({shown})"]
    return [f"{name} {_label(new)}: {old[1]:.2f} € -> {new[1]:.2f} €"
            for new, old in zip(official, ours) if new[1] != old[1]]


def differences(text, year, import_cost, ownership_cost, schema):
    found = []
    for name, parse, ours in [
        ("isvBands", parse_isv, dart_bands(import_cost, "isvBands")),
        ("iucBands", parse_iuc, dart_bands(ownership_cost, "iucBands")),
    ]:
        try:
            first, official = parse(text)
        except TableNotFound as error:
            found.append(f"Não foi possível ler {error} do PDF de {year}")
            continue
        if first != FIRST_CHARGED_CC:
            found.append(f"{name}: a tabela começa agora em {first} cc")
        found += compare(name, official, ours)
        if name == "isvBands":
            found += compare("motorcycle_isv", official, sql_bands(schema))
    for name, source in [("isvTableYear", import_cost), ("iucTableYear", ownership_cost)]:
        if dart_year(source, name) < year:
            found.append(f"{name} ainda é {dart_year(source, name)}")
    return found


def download(year, folder):
    """The year's PDF in `folder`, or None when it isn't published yet."""
    path = os.path.join(folder, f"SFP-Taxas-{year}.pdf")
    request = urllib.request.Request(PDF_URL.format(year=year),
                                     headers={"User-Agent": "motorcycle-deal-tracker tax check"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response, open(path, "wb") as out:
            out.write(response.read())
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise
    return path


def pdf_text(path):
    return subprocess.run(["pdftotext", "-layout", path, "-"], check=True,
                          capture_output=True, text=True).stdout


def summary(year, found, published=True):
    if not published:
        return f"## Tabelas de impostos {year}\n\nO PDF de {year} ainda não foi publicado.\n"
    if not found:
        return (f"## Tabelas de impostos {year}\n\n"
                "ISV (Tabela C) e IUC (categoria E) iguais aos da app e da base de dados.\n")
    lines = "".join(f"- {line}\n" for line in found)
    return f"## Tabelas de impostos {year}\n\nDiferenças com {PDF_URL.format(year=year)}:\n\n{lines}"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--year", type=int, default=datetime.date.today().year)
    parser.add_argument("--pdf", help="a PDF already downloaded")
    parser.add_argument("--json-out", help="where to write the differences as JSON")
    parser.add_argument("--repo", default=".")
    args = parser.parse_args(argv)

    def read(path):
        with open(os.path.join(args.repo, path), encoding="utf-8") as source:
            return source.read()

    with tempfile.TemporaryDirectory() as folder:
        pdf = args.pdf or download(args.year, folder)
        found = None if pdf is None else differences(
            pdf_text(pdf), args.year, read(IMPORT_COST), read(OWNERSHIP_COST), read(SCHEMA))

    text = summary(args.year, found or [], published=found is not None)
    print(text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as out:
            out.write(text)
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as out:
            json.dump({"year": args.year, "differences": found or []}, out, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
