"""Checks web/index.html's script that measures the page again (N.131).

The script runs in Node with a stand-in for the iPhone's window, document
and timers; skipped where Node isn't installed.
"""

import json
import pathlib
import re
import shutil
import subprocess
import unittest

INDEX = pathlib.Path(__file__).resolve().parent.parent / 'app' / 'web' / 'index.html'


def resize_script():
    """The inline script that carries the N.131 comment."""
    scripts = re.findall(r'<script>(.*?)</script>', INDEX.read_text(encoding='utf-8'), re.S)
    found = [s for s in scripts if "The page's size, measured again (N.131)" in s]
    assert len(found) == 1, 'the resize script is missing or repeated'
    return found[0]


# Runs the script, then the steps: ['size', w, h] changes the page,
# ['tick', n] runs the timer n times, ['event', target, name] sends a
# browser event, ['visibility', state] changes document.visibilityState.
# Prints what happened: the resize events the script sent (`sent`), and
# whether a timer is running.
HARNESS = r'''
const steps = JSON.parse(process.argv[1]);
const ios = JSON.parse(process.argv[2]);
const script = process.argv[3];

let timers = new Map();
let nextTimer = 1;
const page = { w: 390, h: 800 };
const viewport = new EventTarget();
Object.defineProperty(viewport, 'width', { get: () => page.w });
Object.defineProperty(viewport, 'height', { get: () => page.h });
let sent = 0;
viewport.addEventListener('resize', () => { sent += 1; });

const win = new EventTarget();
win.visualViewport = viewport;
const doc = new EventTarget();
doc.visibilityState = 'visible';
doc.documentElement = {};
Object.defineProperty(doc.documentElement, 'clientWidth', { get: () => page.w });
Object.defineProperty(doc.documentElement, 'clientHeight', { get: () => page.h });

const context = {
  window: win,
  document: doc,
  navigator: ios ? { standalone: true } : {},
  Event,
  Math,
  setInterval: (fn) => { const id = nextTimer++; timers.set(id, fn); return id; },
  clearInterval: (id) => { timers.delete(id); },
};
new Function(...Object.keys(context), script)(...Object.values(context));

const log = [];
for (const step of steps) {
  if (step[0] === 'size') { page.w = step[1]; page.h = step[2]; }
  if (step[0] === 'tick') {
    for (let i = 0; i < step[1]; i++) for (const fn of [...timers.values()]) fn();
  }
  if (step[0] === 'event') {
    (step[1] === 'document' ? doc : win).dispatchEvent(new Event(step[2]));
  }
  if (step[0] === 'visibility') doc.visibilityState = step[1];
  log.push({ sent, timers: timers.size });
}
console.log(JSON.stringify(log));
'''


def run(steps, ios=True):
    node = shutil.which('node')
    out = subprocess.run(
        [node, '-e', HARNESS, '--', json.dumps(steps), json.dumps(ios), resize_script()],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)


@unittest.skipUnless(shutil.which('node'), 'Node is not installed')
class WebResizeTest(unittest.TestCase):
    def test_a_height_settled_later_is_sent_once(self):
        log = run([['tick', 1], ['size', 390, 750], ['tick', 1], ['tick', 3]])
        self.assertEqual([s['sent'] for s in log], [0, 0, 1, 1])

    def test_a_window_resize_is_checked_at_once(self):
        log = run([['tick', 40], ['size', 844, 390], ['event', 'window', 'resize'],
                   ['event', 'window', 'resize']])
        self.assertEqual([s['sent'] for s in log], [0, 0, 1, 1])

    def test_the_timer_stops_after_ten_seconds(self):
        log = run([['tick', 39], ['tick', 1]])
        self.assertEqual([s['timers'] for s in log], [1, 0])

    def test_a_return_to_the_app_watches_again(self):
        log = run([
            ['tick', 40],
            ['visibility', 'hidden'], ['event', 'document', 'visibilitychange'],
            ['visibility', 'visible'], ['event', 'document', 'visibilitychange'],
            ['size', 390, 760], ['tick', 1],
        ])
        self.assertEqual([s['timers'] for s in log], [0, 0, 0, 0, 1, 1, 1])
        self.assertEqual(log[-1]['sent'], 1)

    def test_launch_events_restart_one_timer(self):
        for event in ('pageshow', 'orientationchange', 'flutter-first-frame'):
            with self.subTest(event=event):
                log = run([['tick', 40], ['event', 'window', event], ['tick', 20],
                           ['event', 'window', event]])
                self.assertEqual([s['timers'] for s in log], [0, 1, 1, 1])

    def test_nothing_outside_the_iphone(self):
        log = run([['tick', 1], ['size', 390, 750], ['event', 'window', 'resize'],
                   ['tick', 1]], ios=False)
        self.assertEqual(log[-1], {'sent': 0, 'timers': 0})


if __name__ == '__main__':
    unittest.main()
