.DEFAULT_GOAL := help
.PHONY: help app-get app-run app-check app-build app-serve \
        collector-get collector-check collect-dry collect \
        db-push db-new db-test sql-lint check tool-check lint-scripts format clean mutation \
        coverage duplication dead-code \
        require-collector-env require-file

# Which source the collector reads: manual (a JSON file), standvirtual
# (a folder of saved listing pages), standvirtual-search or olx-search
# (folders of search pages). Extra collector flags go in ARGS.
SOURCE ?= manual
# Which website make searches/fetch work on: standvirtual or olx.
SITE ?= standvirtual
# Local secrets for the collector (not committed). GitHub Actions has no such
# file and uses its repository secrets instead.
-include collector/.env
export SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
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

app-check: ## Analyze and test the app
	cd app && flutter analyze && flutter test

app-build: ## Release web build
	cd app && flutter build web --wasm --dart-define-from-file=env/dev.json

app-serve: app-build ## Serve the release build on http://localhost:8080 (PWA test)
	cd app/build/web && python3 -m http.server 8080

# ---- Collector -------------------------------------------------------------

collector-get: ## Install collector dependencies
	cd collector && dart pub get

collector-check: ## Format check, analyze and test the collector
	cd collector && dart format --output=none --set-exit-if-changed . && dart analyze && dart test

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

notify-test: require-collector-env ## Send a test message to Telegram
	cd collector && dart run bin/notify_test.dart

push-test: require-collector-env ## Send a test notification to the admins' devices (Web Push)
	cd collector && dart run bin/push_test.dart

weekly-summary: require-collector-env ## Make and send each account's weekly summary (Web Push): make weekly-summary [ARGS=--dry-run]
	cd collector && dart run bin/weekly_summary.dart $(ARGS)

enrich-dry: require-collector-env ## List the listings that still need details, requests nothing
	cd collector && dart run bin/enrich.dart --dry-run

enrich: require-collector-env ## Read details of up to 15 new listings: make enrich [ARGS=--max=10]
	cd collector && dart run bin/enrich.dart $(ARGS)

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

sql-lint: db-test ## Static checks of the database: plpgsql_check, splinter, squawk on new migrations
	tool/sql_lint.sh

# ---- Everything ------------------------------------------------------------

tool-check: ## Test the helper scripts in tool/ (Python)
	python3 -m unittest discover -s tool -p 'test_*.py'

lint-scripts: ## Lint the workflows (actionlint, with shellcheck on their run: steps) and the shell scripts
	actionlint
	shellcheck tool/*.sh .claude/hooks/*.sh

check: app-check collector-check tool-check ## Run all checks (run before committing)

# Floors for `make coverage` (line coverage, %). Raise them as tests are
# added; lower one only with a reason in the commit. The app's floor counts
# its logic (texts, entities, models, cubits), not the widgets.
APP_COVERAGE_MIN ?= 90
COLLECTOR_COVERAGE_MIN ?= 70
APP_LOGIC_FILES = _text\.dart$$|/domain/|/data/models/|/cubit/|ownership_cost\.dart$$|viewing_checklist\.dart$$

coverage: ## Test coverage of app logic and collector, with floors (needs `dart pub global activate coverage`)
	cd app && flutter test --coverage
	cd collector && dart test --coverage=coverage && dart pub global run coverage:format_coverage \
	  --lcov --in=coverage --out=coverage/lcov.info --report-on=lib --package=.
	python3 tool/lcov_summary.py app/coverage/lcov.info --name app \
	  --only '$(APP_LOGIC_FILES)' --min $(APP_COVERAGE_MIN)
	python3 tool/lcov_summary.py collector/coverage/lcov.info --name collector \
	  --min $(COLLECTOR_COVERAGE_MIN)

duplication: ## Copy-pasted code above 1 % of the lines fails (jscpd, via npx)
	npx --yes jscpd@4 --min-tokens 70 --format dart --threshold 1 \
	  --reporters console --ignore '**/*.g.dart' app/lib collector/lib collector/bin

# Unused code (declarations nothing in lib uses) and unused files in the
# app: dart_code_linter, pinned. Not the collector: lib/collector.dart
# exports every file, and exported code counts as used (public API).
DCL = dart pub global run dart_code_linter:metrics

dead-code: ## Unused code and files in the app (needs Flutter and `dart pub global activate dart_code_linter 4.4.2`)
	cd app && $(DCL) check-unused-code lib --fatal-unused --no-congratulate
	cd app && $(DCL) check-unused-files lib test --fatal-unused --no-congratulate

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