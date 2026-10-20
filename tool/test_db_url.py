"""Tests for tool/db_url.py: python3 -m unittest discover -s tool -p 'test_*.py'"""

import unittest
from urllib.parse import unquote, urlsplit

from db_url import DbUrlError, build_db_url

POOLER = ("postgresql://postgres.abcdefgh:[YOUR-PASSWORD]"
          "@aws-0-eu-west-3.pooler.supabase.com:5432/postgres")


def password_of(url):
    return unquote(urlsplit(url).password)


class BuildDbUrlTest(unittest.TestCase):
    def test_the_placeholder_takes_the_encoded_password(self):
        url = build_db_url(POOLER, "Moto!2024*abc?")
        self.assertIn(":Moto%212024%2Aabc%3F@", url)
        self.assertEqual(password_of(url), "Moto!2024*abc?")
        self.assertEqual(urlsplit(url).hostname, "aws-0-eu-west-3.pooler.supabase.com")
        self.assertEqual(urlsplit(url).port, 5432)

    def test_every_awkward_character_survives(self):
        for password in ["a@b#c/d%e", "p:w?x&y=z", "sp ace", "ãé€", "]["]:
            with self.subTest(password=password):
                self.assertEqual(password_of(build_db_url(POOLER, password)), password)

    def test_the_placeholder_without_brackets(self):
        url = build_db_url(POOLER.replace("[YOUR-PASSWORD]", "YOUR-PASSWORD"), "x!y")
        self.assertEqual(password_of(url), "x!y")

    def test_a_password_in_the_url_is_replaced_by_the_secret(self):
        url = build_db_url(POOLER.replace("[YOUR-PASSWORD]", "old!?pass"), "new*pw")
        self.assertEqual(password_of(url), "new*pw")
        self.assertEqual(urlsplit(url).username, "postgres.abcdefgh")

    def test_a_url_with_an_encoded_password_alone_is_used_as_it_is(self):
        url = POOLER.replace("[YOUR-PASSWORD]", "Moto%21%3F")
        self.assertEqual(build_db_url(url), url + "?sslmode=require")

    def test_tls_is_required_unless_the_url_says_otherwise(self):
        self.assertEqual(urlsplit(build_db_url(POOLER, "pw")).query, "sslmode=require")
        url = POOLER.replace("[YOUR-PASSWORD]", "pw") + "?sslmode=verify-full"
        self.assertEqual(urlsplit(build_db_url(url)).query, "sslmode=verify-full")

    def test_quotes_spaces_and_newlines_from_pasting_are_dropped(self):
        url = build_db_url(f'  "{POOLER}"\n', "pw!\n")
        self.assertEqual(password_of(url), "pw!")

    def test_problems_are_named_without_the_secret(self):
        cases = {
            "": "Set the SUPABASE_DB_URL",
            "https://example.com": "must start with postgresql://",
            POOLER: "still says [YOUR-PASSWORD]",
            POOLER.replace("[YOUR-PASSWORD]", "a?b"): "cannot be read",
            "postgresql://postgres@host:5432/postgres": "needs a user, a password and a host",
            "postgresql://u:p@host/postgres": "has no port",
            "postgresql://postgres:p@db.abcdefgh.supabase.co:5432/postgres":
                "is the Direct connection",
        }
        for url, message in cases.items():
            with self.subTest(url=url):
                with self.assertRaises(DbUrlError) as raised:
                    build_db_url(url)
                self.assertIn(message, str(raised.exception))
                if url:
                    self.assertNotIn(url, str(raised.exception))


if __name__ == "__main__":
    unittest.main()
