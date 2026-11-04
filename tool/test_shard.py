"""The test files of one CI shard: every `*_test.dart` under a package's
test/ directory, split into SHARDS groups of about the same size, printed
relative to the package (`test/x_test.dart`) for `flutter test` or
`dart test`.

    python3 tool/test_shard.py app 2 0     # the first of two shards

Split by file, not with the runners' --total-shards (which splits the
test cases of every file, so each shard would still compile every file:
most of a Flutter test run). Sizes are the files' bytes, a stable stand-in
for their run time; the biggest files go first, each to the lightest
shard so far (ties by name), so the split only changes when the tests do.
Every file lands in exactly one shard; an empty shard is an error (a
runner given no file would run them all). Used by the Makefile's
app-test-coverage / collector-test-coverage and check.yml; tests:
tool/test_test_shard.py.
"""

import os
import sys


def test_files(package):
    """Every `*_test.dart` under package/test, relative to package, sorted."""
    root = os.path.join(package, "test")
    found = []
    for folder, _, names in os.walk(root):
        for name in names:
            if name.endswith("_test.dart"):
                found.append(os.path.relpath(os.path.join(folder, name), package))
    return sorted(found)


def shards(sizes, total):
    """[[file, ...] per shard] from {file: size}: biggest first, each to the
    lightest shard so far (the lowest index on a tie); each shard sorted."""
    groups = [[] for _ in range(total)]
    weights = [0] * total
    for name in sorted(sizes, key=lambda n: (-sizes[n], n)):
        lightest = min(range(total), key=lambda i: (weights[i], i))
        groups[lightest].append(name)
        weights[lightest] += sizes[name]
    return [sorted(g) for g in groups]


def main(argv):
    if len(argv) != 3:
        print("Usage: test_shard.py <package> <shards> <index>", file=sys.stderr)
        return 64
    package, total, index = argv[0], int(argv[1]), int(argv[2])
    if total < 1 or not 0 <= index < total:
        print(f"Shard {index} of {total} does not exist.", file=sys.stderr)
        return 64
    files = test_files(package)
    if not files:
        print(f"No *_test.dart under {package}/test.", file=sys.stderr)
        return 1
    sizes = {f: os.path.getsize(os.path.join(package, f)) for f in files}
    chosen = shards(sizes, total)[index]
    if not chosen:
        # The runner given no file runs every test: say so instead.
        print(f"Shard {index} of {total} has no test file (fewer shards).", file=sys.stderr)
        return 1
    print(" ".join(chosen))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
