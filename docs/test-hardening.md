# Test-hardening backlog

Worked through by `.github/workflows/test-hardening.yml` (Claude, like a
mutation-testing tool such as Stryker) after every 5 merged PRs or by
"Run workflow". Each run does one of two things:

- **"To do" is empty → find run:** it only looks, and changes no code. It
  hunts for bugs with hostile inputs (proven by a failing throwaway test),
  makes small temporary changes to the code to find code whose tests don't
  notice a change ("surviving mutants"), and spots redundant tests. It
  writes up to 10 items, most valuable first.
- **"To do" has items → fix run:** it does up to 3 of them (all if fewer
  are left): a bug gets its failing test first, then the fix; a surviving
  mutant gets the test that catches it; a redundant test is dropped once
  the other one is checked to cover the same. It does not look for new
  items.

Fixes may only make the code do what CLAUDE.md, the comments or the
function's name say; anything changing the fetching, scoring or alert
rules, the database schema, secrets or workflows goes to "Needs Rafael".
SQL is left out (CI has no database). Rafael can add, remove or reorder
items by hand at any time.

## To do

## Needs Rafael

## Done
