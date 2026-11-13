"""Checks tool/web_preconnect.sh: the database tags and the engine version."""

import pathlib
import subprocess
import tempfile
import unittest

TOOL = pathlib.Path(__file__).resolve().parent
SCRIPT = TOOL / 'web_preconnect.sh'
INDEX = TOOL.parent / 'app' / 'web' / 'index.html'
ENGINE = 'cf636b1dfb818dd6a3ff16e390e93b1a036969c8'


class WebPreconnectTest(unittest.TestCase):
    def run_script(self, bootstrap):
        folder = pathlib.Path(tempfile.mkdtemp())
        index = folder / 'index.html'
        index.write_text(INDEX.read_text(encoding='utf-8'), encoding='utf-8')
        if bootstrap is not None:
            (folder / 'flutter_bootstrap.js').write_text(bootstrap, encoding='utf-8')
        result = subprocess.run(
            ['bash', str(SCRIPT), str(index), 'https://db.example', 'key'],
            capture_output=True, text=True, check=False)
        return result, index.read_text(encoding='utf-8')

    def test_engine_version_from_the_bootstrap(self):
        result, html = self.run_script(
            '_flutter.buildConfig = {"engineRevision":"%s","builds":[]};' % ENGINE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('<meta name="flutter-engine" content="%s">' % ENGINE, html)
        self.assertIn('<link rel="preconnect" href="https://db.example" crossorigin>', html)
        # Before the preload script, which reads it.
        self.assertLess(html.index('name="flutter-engine"'),
                        html.index("meta[name=\"flutter-engine\"]"))

    def test_no_bootstrap_no_engine(self):
        result, html = self.run_script(None)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('<meta name="flutter-engine" content=', html)

    def test_bootstrap_without_a_version_fails(self):
        result, _ = self.run_script('_flutter.buildConfig = {"builds":[]};')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('engineRevision', result.stderr)


if __name__ == '__main__':
    unittest.main()
