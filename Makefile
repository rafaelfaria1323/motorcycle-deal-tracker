.DEFAULT_GOAL := help
.PHONY: help app-get app-run app-check app-build app-serve \
        collector-get collector-check collect-dry collect \
        db-push db-new check format clean \
        require-collector-env require-file

# Which source the collector reads: manual (a JSON file) or standvirtual
# (a folder of saved listing pages). Extra collector flags go in ARGS.
SOURCE ?= manual
# Local secrets for the collector (not committed). GitHub Actions has no such
# file and uses its repository secrets instead.
-include collector/.env
export SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY
ifeq ($(SOURCE),standvirtual)
DEFAULT_INPUT := samples/standvirtual
else ifeq ($(SOURCE),standvirtual-search)
DEFAULT_INPUT := samples/standvirtual/search
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
	cd app && flutter build web --dart-define-from-file=env/dev.json

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

fetch-dry: ## Check the search addresses and limits, requests nothing
	cd collector && dart run bin/fetch.dart standvirtual sources/standvirtual_searches.txt --dry-run

fetch: ## Download the search pages, slowly and capped (see collector/lib/src/fetch)
	cd collector && dart run bin/fetch.dart standvirtual sources/standvirtual_searches.txt $(ARGS)

enrich-dry: require-collector-env ## List the listings that still need details, requests nothing
	cd collector && dart run bin/enrich.dart --dry-run

enrich: require-collector-env ## Read details of up to 15 new listings: make enrich [ARGS=--max=10]
	cd collector && dart run bin/enrich.dart $(ARGS)

refresh: require-collector-env ## Fetch search pages, import them, read new listings' details: make refresh [ARGS=--full]
	rm -f collector/samples/standvirtual/search/*.html
	$(MAKE) fetch ARGS=
	$(MAKE) collect SOURCE=standvirtual-search FILE=samples/standvirtual/search ARGS="$(ARGS)"
	$(MAKE) enrich ARGS=--max=10

# ---- Database --------------------------------------------------------------

db-push: ## Apply new migrations to the linked Supabase project
	supabase db push

db-new: ## Create a migration: make db-new NAME=add_something
	@test -n "$(NAME)" || (echo "Usage: make db-new NAME=add_something"; exit 1)
	supabase migration new $(NAME)

# ---- Everything ------------------------------------------------------------

check: app-check collector-check ## Run all checks (run before committing)

format: ## Format app and collector code
	dart format app/lib app/test collector

clean: ## Remove build artifacts
	cd app && flutter clean
	rm -rf collector/.dart_tool

# ---- Guards ----------------------------------------------------------------

require-collector-env:
	@test -n "$$SUPABASE_URL" || (echo "SUPABASE_URL is not set"; exit 1)
	@test -n "$$SUPABASE_SERVICE_ROLE_KEY" || (echo "SUPABASE_SERVICE_ROLE_KEY is not set"; exit 1)

require-file:
	@test -n "$(FILE)" || (echo "Usage: make collect [SOURCE=standvirtual] FILE=imports/my_listings.json"; exit 1)