.DEFAULT_GOAL := help
.PHONY: help app-get app-run app-analyze app-check app-smoke app-build app-serve \
        collector-get collector-lint collector-check collect-dry collect \
        db-push db-new db-test sql-lint schema check tool-check lint-scripts format clean mutation \
        coverage app-coverage collector-coverage duplication dead-code \
        app-test-coverage app-coverage-floor collector-test-coverage collector-coverage-floor \
        require-collector-env require-file

# Which source the collector reads: manual (a JSON file), standvirtual
# (a folder of saved listing pages), standvirtual-search or olx-search
# (folders of search pages). Extra collector flags go in ARGS.
SOURCE ?= manual
# Which website make searches/fetch work on: standvirtual or olx.
SITE ?= standvirtual
# The Python of make tool-check.
PYTHON ?= python3
# Local secrets for the collector (not committed). GitHub Actions has no such
# file and uses its repository secrets instead.
-include collector/.env
export SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY
ifeq ($(SOURCE),standvirtual)
DEFAULT_INPUT := samples/standvirtual
else ifeq ($(SOURCE),standvirtual-search)
DEFAULT_INPUT := samples/standvirtual/search
else ifeq ($(SOURCE),olx-search)
DEFAULT_INPUT := samples/olx/search
else
DEFAULT_INPUT := samples/manual_sample.json
endif

help: ## Show this list
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

# ---- Flutter app -----------------------------------------------------------

app-get: ## Install app dependencies
	cd app && flutter pub get

app-run: ## Run the app in Chrome (uses app/env/dev.json)
	cd app && flutter run -d chrome --dart-define-from-file=env/dev.json

app-analyze: ## Analyze the app
	cd app && flutter analyze

app-check: app-analyze ## Analyze and test the app
	cd app && flutter test

app-smoke: ## Offline Chrome smoke test (needs matching ChromeDriver on PATH)
	bash tool/app_smoke.sh

app-build: ## Release web build
	cd app && flutter build web --wasm --dart-define-from-file=env/dev.json

app-serve: app-build ## Serve the release build on http://localhost:8080 (PWA test)
	cd app/build/web && python3 -m http.server 8080

# ---- Collector -------------------------------------------------------------

collector-get: ## Install collector dependencies
	cd collector && dart pub get

collector-lint: ## Format check and analyze the collector
	cd collector && dart format --output=none --set-exit-if-changed . && dart analyze

collector-check: collector-lint ## Format check, analyze and test the collector
	cd collector && dart test

collect-dry: require-collector-env ## Preview, writes nothing: make collect-dry [SOURCE=standvirtual] [FILE=...]
	cd collector && dart run bin/collector.dart $(SOURCE) $(or $(FILE),$(DEFAULT_INPUT)) --dry-run $(ARGS)

collect: require-collector-env require-file ## Import: make collect [SOURCE=standvirtual] FILE=... [ARGS=--full]
	cd collector && dart run bin/collector.dart $(SOURCE) $(FILE) $(ARGS)

searches: require-collector-env ## Write the searches of the tracked models: make searches [SITE=olx]
	cd collector && dart run bin/searches.dart $(SITE) --out=.searches.$(SITE).txt

fetch-dry: searches ## Check the search addresses and limits, requests nothing: make fetch-dry [SITE=olx]
	cd collector && dart run bin/fetch.dart $(SITE) .searches.$(SITE).txt --dry-run

fetch: searches ## Download the search pages, slowly and capped: make fetch [SITE=olx]
	cd collector && dart run bin/fetch.dart $(SITE) .searches.$(SITE).txt $(ARGS)

push-test: require-collector-env ## Send a test notification to the admins' devices (Web Push)
	cd collector && dart run bin/push_test.dart

weekly-summary: require-collector-env ## Make and send each account's weekly summary (Web Push): make weekly-summary [ARGS=--dry-run]
	cd collector && dart run bin/weekly_summary.dart $(ARGS)

text-audit: require-collector-env ## The description check (N.55): the rules against Gemini on the week's ads; needs GEMINI_API_KEY: make text-audit [ARGS=--ads=20]
	cd collector && dart run bin/text_audit.dart $(ARGS)

model-specs: require-collector-env ## The catalog's missing figures from API Ninjas (N.76, API_NINJAS_KEY): make model-specs
	cd collector && dart run bin/model_specs.dart $(ARGS)

score-check: require-collector-env ## The estimates and Deal Score against likely sales (N.61): make score-check [ARGS=--days=14]
	cd collector && dart run bin/score_check.dart $(ARGS)

enrich-dry: require-collector-env ## List the listings that still need details, requests nothing
	cd collector && dart run bin/enrich.dart --dry-run

enrich: require-collector-env ## Read details of up to 10 new listings: make enrich [ARGS=--max=5]
	cd collector && dart run bin/enrich.dart $(ARGS)

photos-dry: require-collector-env ## List the listings whose photos wait for fingerprints, requests nothing
	cd collector && dart run bin/photos.dart --dry-run

photos: require-collector-env ## Fingerprint up to 3 photos of new listings (photo CDN, 5 min): make photos [ARGS=--max=50]
	cd collector && dart run bin/photos.dart $(ARGS)

# One process for the whole collection (bin/refresh.dart): each site's
# searches are fetched and imported, Standvirtual's new listings get their
# details with the same fetcher, then duplicates, scores, alerts and
# notifications run once. A site that fails does not stop the other, but the
# refresh still fails.
refresh: require-collector-env ## Fetch and import both sites: make refresh [ARGS=--full]
	cd collector && dart run bin/refresh.dart $(ARGS)

refresh-standvirtual: require-collector-env ## Standvirtual only: search pages, import, new listings' details
	cd collector && dart run bin/refresh.dart --site=standvirtual $(ARGS)

refresh-olx: require-collector-env ## OLX only: every page of each search, import
	cd collector && dart run bin/refresh.dart --site=olx $(ARGS)

# ---- Database --------------------------------------------------------------

db-push: ## Apply new migrations to the linked Supabase project
	supabase db push

db-new: ## Create a migration: make db-new NAME=add_something
	@test -n "$(NAME)" || (echo "Usage: make db-new NAME=add_something"; exit 1)
	supabase migration new $(NAME)

db-test: ## Apply every migration to a fresh local Postgres and run supabase/tests (PGHOST, PGUSER, ...)
	tool/db_test.sh

sql-lint: db-test ## Static checks of the database: plpgsql_check, splinter, squawk on new migrations, safeupdate, schema.sql
	tool/sql_lint.sh

schema: db-test ## Rewrite supabase/schema.sql, the schema the migrations produce (read only, never applied)
	tool/schema_snapshot.sh

# ---- Everything ------------------------------------------------------------

tool-check: ## Test the helper scripts in tool/ (Python; PYTHON=... with tool/photo_requirements.txt runs the photo model's tests too)
	$(PYTHON) -m unittest discover -s tool -p 'test_*.py'

lint-scripts: ## Lint the workflows (actionlint, with shellcheck on their run: steps) and the shell scripts
	actionlint
	shellcheck tool/*.sh .claude/hooks/*.sh

check: app-check collector-check tool-check ## Run all checks (run before committing)

# Floors for `make coverage` (line coverage, %). Raise them as tests are
# added; lower one only with a reason in the commit. The app's floor counts
# its logic (texts, entities, models, cubits), not the widgets.
APP_COVERAGE_MIN ?= 90
COLLECTOR_COVERAGE_MIN ?= 85
APP_LOGIC_FILES = _text\.dart$$|/domain/|/data/models/|/cubit/|/core/formatting/|/core/localization/|/language_cubit\.dart$$|/supabase_language_repository\.dart$$|ownership_cost\.dart$$|viewing_checklist\.dart$$

# The coverage targets run the tests themselves (a failing test fails
# them), so CI runs app-analyze / collector-lint plus these instead of
# make check: each test suite once.
coverage: app-coverage collector-coverage ## Test coverage of app logic and collector, with floors (needs `dart pub global activate coverage`)

app-coverage: app-test-coverage app-coverage-floor ## The app's tests with coverage and its floor

collector-coverage: collector-test-coverage collector-coverage-floor ## The collector's tests with coverage and its floor (needs `dart pub global activate coverage`)

# check.yml runs each suite in parallel jobs, as many and with the files
# tool/test_shard.py plans from the last run's times; each job gets its
# files in the environment variable TEST_FILES. Without it, SHARDS and
# SHARD (0-based) pick the files here (split by size). Each run leaves
# coverage/tests.jsonl (the runner's JSON report: each file's time), and
# the floor is then taken once over every shard's lcov, merged line by
# line (APP_LCOV / COLLECTOR_LCOV, shell globs). By default one shard:
# every test.
SHARDS ?= 1
SHARD ?= 0
APP_LCOV ?= app/coverage/lcov.info
COLLECTOR_LCOV ?= collector/coverage/lcov.info

app-test-coverage: ## The app's tests (TEST_FILES, or one shard: SHARDS=n SHARD=i) with coverage, no floor
	files="$${TEST_FILES:-$$(python3 tool/test_shard.py app $(SHARDS) $(SHARD))}" && \
	  cd app && flutter test --coverage --file-reporter json:.dart_tool/tests.jsonl $$files && \
	  cp .dart_tool/tests.jsonl coverage/tests.jsonl

app-coverage-floor: ## The app's coverage floor over APP_LCOV (every shard's lcov)
	python3 tool/lcov_summary.py $(APP_LCOV) --name app \
	  --only '$(APP_LOGIC_FILES)' --min $(APP_COVERAGE_MIN)

collector-test-coverage: ## The collector's tests (TEST_FILES, or one shard: SHARDS=n SHARD=i) with coverage, no floor
	files="$${TEST_FILES:-$$(python3 tool/test_shard.py collector $(SHARDS) $(SHARD))}" && \
	  cd collector && dart test --coverage=coverage --file-reporter json:.dart_tool/tests.jsonl $$files && \
	  dart pub global run coverage:format_coverage \
	  --lcov --in=coverage --out=coverage/lcov.info --report-on=lib --package=. && \
	  cp .dart_tool/tests.jsonl coverage/tests.jsonl

collector-coverage-floor: ## The collector's coverage floor over COLLECTOR_LCOV (every shard's lcov)
	python3 tool/lcov_summary.py $(COLLECTOR_LCOV) --name collector \
	  --min $(COLLECTOR_COVERAGE_MIN)

duplication: ## Copy-pasted code above 1 % of the lines fails (jscpd, via npx)
	npx --yes jscpd@4 --min-tokens 70 --format dart --threshold 1 \
	  --reporters console --ignore '**/*.g.dart,**/l10n/generated/**' app/lib collector/lib collector/bin

# Unused code (declarations nothing in lib uses) and unused files in the
# app: dart_code_linter, pinned. Not the collector: lib/collector.dart
# exports every file, and exported code counts as used (public API).
DCL = dart pub global run dart_code_linter:metrics
DCL_EXCLUDE = --exclude '{/**.g.dart,/**.freezed.dart,lib/l10n/generated/**}'

dead-code: ## Unused code and files in the app (needs Flutter and `dart pub global activate dart_code_linter 4.4.2`)
	cd app && $(DCL) check-unused-code lib $(DCL_EXCLUDE) --fatal-unused --no-congratulate
	cd app && $(DCL) check-unused-files lib test $(DCL_EXCLUDE) --fatal-unused --no-congratulate

format: ## Format app and collector code
	dart format app/lib app/test collector

mutation: ## Mutation testing (needs `dart pub global activate mutation_test`): make mutation PKG=collector FILES="lib/src/catalog/model_resolver.dart"
	python3 -I tool/mutation.py run $(PKG) .mutation-report $(FILES)
	python3 -I tool/mutation.py summary .mutation-report

clean: ## Remove build artifacts
	cd app && flutter clean
	rm -rf collector/.dart_tool

# ---- Guards ----------------------------------------------------------------

require-collector-env:
	@test -n "$$SUPABASE_URL" || (echo "SUPABASE_URL is not set"; exit 1)
	@test -n "$$SUPABASE_SERVICE_ROLE_KEY" || (echo "SUPABASE_SERVICE_ROLE_KEY is not set"; exit 1)

require-file:
	@test -n "$(FILE)" || (echo "Usage: make collect [SOURCE=standvirtual] FILE=imports/my_listings.json"; exit 1)