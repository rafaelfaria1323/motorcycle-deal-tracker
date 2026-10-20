"""Builds the database URL for `supabase db push` from two secrets.

SUPABASE_DB_URL       Supabase > Connect > Session pooler string, as shown
                      ("[YOUR-PASSWORD]" in it), or with the password filled in.
SUPABASE_DB_PASSWORD  The database password as typed (optional when the URL
                      already holds it).

The password is URL-encoded here, so characters such as ! * ? @ # work.
Prints the URL; on a problem prints a GitHub error (never the secret) and
exits 1. Used by .github/workflows/deploy-web.yml; tests: tool/test_db_url.py.
"""

import os
import sys
from urllib.parse import quote, urlsplit, urlunsplit

PLACEHOLDERS = ("[YOUR-PASSWORD]", "YOUR-PASSWORD")


class DbUrlError(ValueError):
    pass


def _clean(value):
    value = (value or "").strip()
    # Pasted with quotes around it.
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1].strip()
    return value


def build_db_url(url, password=None):
    url = _clean(url)
    password = (password or "").strip("\r\n")
    if not url:
        raise DbUrlError("Set the SUPABASE_DB_URL secret (see docs/hosting.md)")
    if not url.startswith(("postgresql://", "postgres://")):
        raise DbUrlError(
            "SUPABASE_DB_URL must start with postgresql:// (copy the Session "
            "pooler connection string from Supabase > Connect)")

    placeholder = next((p for p in PLACEHOLDERS if p in url), None)
    if password:
        encoded = quote(password, safe="")
        if placeholder:
            url = url.replace(placeholder, encoded)
        else:
            # Replace whatever password the URL holds (or add one).
            scheme, rest = url.split("://", 1)
            userinfo, sep, host = rest.rpartition("@")
            if not sep:
                raise DbUrlError("SUPABASE_DB_URL has no user@host part")
            user = userinfo.split(":", 1)[0]
            url = f"{scheme}://{user}:{encoded}@{host}"
    elif placeholder:
        raise DbUrlError(
            "SUPABASE_DB_URL still says [YOUR-PASSWORD]: set the "
            "SUPABASE_DB_PASSWORD secret to the database password")

    try:
        parts = urlsplit(url)
        port = parts.port
    except ValueError:
        raise DbUrlError(
            "SUPABASE_DB_URL cannot be read: put the password in the "
            "SUPABASE_DB_PASSWORD secret and keep [YOUR-PASSWORD] in the URL")
    if not parts.hostname or not parts.username or not parts.password:
        raise DbUrlError(
            "SUPABASE_DB_URL needs a user, a password and a host "
            "(postgresql://user:password@host:port/postgres)")
    if port is None:
        raise DbUrlError("SUPABASE_DB_URL has no port (the Session pooler uses 5432)")
    if parts.hostname.startswith("db.") and parts.hostname.endswith(".supabase.co"):
        # The direct connection: IPv6 only, and GitHub's runners have no IPv6.
        raise DbUrlError(
            "SUPABASE_DB_URL is the Direct connection (db....supabase.co), which "
            "GitHub cannot reach: in Supabase > Connect pick \"Session pooler\" "
            "(host ...pooler.supabase.com, user postgres.<project>) and copy that")
    return urlunsplit(parts)


def main():
    try:
        print(build_db_url(os.environ.get("SUPABASE_DB_URL"),
                           os.environ.get("SUPABASE_DB_PASSWORD")))
    except DbUrlError as e:
        print(f"::error::{e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
