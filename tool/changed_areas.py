"""Which of check.yml's jobs a pull request needs, from the files it changes.

    gh api repos/OWNER/REPO/pulls/N/files --paginate \\
      --jq '.[] | .filename, (.previous_filename // empty)' \\
      | python3 tool/changed_areas.py

prints `app=true|false`, `collector=true|false` and `db=true|false`, the
lines check.yml's `plan` job adds to its outputs:
- app: the app's analysis, tests and smoke (Flutter);
- collector: the collector's tests;
- db: the job collector-db (migrations, workflows and scripts, the
  collector's analysis, tool/, copy-paste, the database).
A change to documentation only (any `.md`, docs/, the licence, Claude's
settings and skills) needs none of them. Anything this file doesn't know
needs all three, so a new kind of file is checked in full until it is
added here. Tests: tool/test_changed_areas.py.
"""

import sys

AREAS = ("app", "collector", "db")

# Files read by tests of both packages (districts, the shortcut script,
# push hosts, the text audit compare with the schema snapshot).
SHARED = {"supabase/schema.sql"}

# Files that drive the test jobs themselves: every job runs.
EVERYTHING = {
    "Makefile",
    ".github/workflows/check.yml",
    "tool/test_shard.py",
    "tool/lcov_summary.py",
}


def is_documentation(path):
    return (path.endswith(".md")
            or path.startswith("docs/")
            or path == "LICENSE"
            or (path.startswith(".claude/") and not path.startswith(".claude/hooks/")))


def areas_of(path):
    """The areas one changed file needs."""
    if is_documentation(path):
        return set()
    if path in EVERYTHING:
        return set(AREAS)
    if path in SHARED:
        return {"app", "collector", "db"}
    if path.startswith("app/") or path == ".fvmrc":
        # collector-db's copy-paste and font checks read the app too.
        return {"app", "db"}
    if (path.startswith("collector/") or path == ".dart-version"
            or path.startswith(".github/actions/collector/")):
        return {"collector", "db"}
    if path.startswith("supabase/migrations/"):
        # The collector's tests read the migrations' RPC names.
        return {"collector", "db"}
    if (path.startswith("supabase/") or path.startswith("tool/") or path == ".squawk.toml"
            or path.startswith(".github/") or path.startswith(".claude/hooks/")):
        return {"db"}
    return set(AREAS)


def needed(paths):
    """{area: bool} for every area, from the changed files' paths."""
    found = set()
    for path in paths:
        path = path.strip()
        if path:
            found |= areas_of(path)
    return {area: area in found for area in AREAS}


def main():
    result = needed(sys.stdin.read().splitlines())
    for area in AREAS:
        print(f"{area}={'true' if result[area] else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
