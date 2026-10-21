"""Lists UPDATE and DELETE statements without a WHERE clause.

Supabase loads pg-safeupdate for requests through its API, which refuses
them even inside a function the request calls. Reads CSV rows (name, body)
of functions on stdin and prints "name: statement" for each one found.
"""

import csv
import re
import sys

_COMMENT = re.compile(r"--[^\n]*|/\*.*?\*/", re.S)
# Dollar-quoted strings with a tag ($job$ ... $job$) and plain '...' ones.
_STRING = re.compile(r"\$(\w+)\$.*?\$\1\$|'(?:[^']|'')*'", re.S)
_STATEMENT = re.compile(
    r"(?<!do\s)\b(?:update\s+(?!set\b)[\w.\"]+(?:\s+(?:as\s+)?\w+)?\s+set|delete\s+from)\b[^;]*",
    re.I,
)


def unsafe_statements(body: str) -> list[str]:
    """The UPDATE and DELETE statements in [body] without a WHERE."""
    text = _STRING.sub("''", _COMMENT.sub(" ", body))
    return [
        " ".join(m.group(0).split())
        for m in _STATEMENT.finditer(text)
        if not re.search(r"\bwhere\b", m.group(0), re.I)
    ]


def main() -> None:
    for row in csv.DictReader(sys.stdin):
        for statement in unsafe_statements(row["body"]):
            print(f"{row['name']}: {statement[:120]}")


if __name__ == "__main__":
    main()
