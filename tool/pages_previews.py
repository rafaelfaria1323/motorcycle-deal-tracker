"""Removes old Cloudflare Pages preview deployments of one pull request.

    python3 tool/pages_previews.py pr-105 --keep-latest   # after a push
    python3 tool/pages_previews.py pr-105                 # PR closed: all

Every push to a PR publishes a new deployment; the alias pr-<number> moves
to the newest, but each older one stays reachable at its own address. This
deletes them (all of them once the PR is closed). Only preview deployments
of a branch named pr-<number> are ever touched, never production (main).
Needs CLOUDFLARE_API_TOKEN (Pages: Edit), CLOUDFLARE_ACCOUNT_ID and
PAGES_PROJECT. Used by .github/workflows/preview-web.yml; tests:
tool/test_pages_previews.py.
"""

import json
import os
import re
import sys
import urllib.request

API = "https://api.cloudflare.com/client/v4"
PREVIEW_BRANCH = re.compile(r"^pr-[0-9]+$")


def branch_of(deployment):
    return ((deployment.get("deployment_trigger") or {}).get("metadata") or {}).get("branch")


def to_delete(deployments, branch, keep_latest):
    """The ids to delete: the branch's preview deployments, newest first,
    without the newest when keep_latest. Refuses anything but pr-<number>."""
    if not PREVIEW_BRANCH.match(branch or ""):
        raise ValueError(f"not a preview branch: {branch!r}")
    mine = [d for d in deployments
            if branch_of(d) == branch and d.get("environment") == "preview"]
    # ISO 8601 times sort as text.
    mine.sort(key=lambda d: d.get("created_on") or "", reverse=True)
    if keep_latest:
        mine = mine[1:]
    return [d["id"] for d in mine]


def _request(method, path, token):
    req = urllib.request.Request(
        API + path, method=method, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def main(argv):
    if not argv or argv[0].startswith("-"):
        print(__doc__, file=sys.stderr)
        return 2
    branch, keep_latest = argv[0], "--keep-latest" in argv[1:]
    token = os.environ["CLOUDFLARE_API_TOKEN"]
    base = (f"/accounts/{os.environ['CLOUDFLARE_ACCOUNT_ID']}"
            f"/pages/projects/{os.environ['PAGES_PROJECT']}/deployments")

    deployments, page = [], 1
    while True:
        body = _request("GET", f"{base}?env=preview&per_page=25&page={page}", token)
        result = body.get("result") or []
        deployments += result
        info = body.get("result_info") or {}
        if not result or page * info.get("per_page", 25) >= info.get("total_count", 0):
            break
        page += 1

    ids = to_delete(deployments, branch, keep_latest)
    for deployment_id in ids:
        # force: also the one the alias points to (when the PR is closed).
        _request("DELETE", f"{base}/{deployment_id}?force=true", token)
    print(f"Deleted {len(ids)} preview deployment(s) of {branch}.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
