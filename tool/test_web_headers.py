"""Checks app/web/_headers, the web app's response headers (N.85)."""

import pathlib
import unittest

HEADERS = pathlib.Path(__file__).resolve().parent.parent / 'app' / 'web' / '_headers'


def site_headers():
    """The headers set for every path (`/*`), by lower-case name."""
    headers = {}
    in_all = False
    for line in HEADERS.read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if not line[0].isspace():
            in_all = line.strip() == '/*'
            continue
        if in_all:
            name, _, value = line.strip().partition(':')
            headers[name.strip().lower()] = value.strip()
    return headers


class WebHeadersTest(unittest.TestCase):
    def test_cross_origin_isolated_without_blocking_photos(self):
        headers = site_headers()
        self.assertEqual(headers['cross-origin-opener-policy'], 'same-origin')
        # require-corp would block the photos: their CDN sends no
        # Cross-Origin-Resource-Policy header.
        self.assertEqual(headers['cross-origin-embedder-policy'], 'credentialless')

    def test_security_headers_kept(self):
        headers = site_headers()
        self.assertIn('max-age=', headers['strict-transport-security'])
        self.assertEqual(headers['x-frame-options'], 'DENY')
        self.assertEqual(headers['x-content-type-options'], 'nosniff')


if __name__ == '__main__':
    unittest.main()
