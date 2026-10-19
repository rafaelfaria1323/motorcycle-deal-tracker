.DEFAULT_GOAL := help
.PHONY: help app-get app-run app-check app-build app-serve \
        collector-get collector-check collect-dry collect \
        db-push db-new check format clean \
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

searches: require-collector-env ## Write the searches of the tracked models: make searches [SITE=olx]
	cd collector && dart run bin/searches.dart $(SITE) --out=.searches.$(SITE).txt

fetch-dry: searches ## Check the search addresses and limits, requests nothing: make fetch-dry [SITE=olx]
	cd collector && dart run bin/fetch.dart $(SITE) .searches.$(SITE).txt --dry-run

fetch: searches ## Download the search pages, slowly and capped: make fetch [SITE=olx]
	cd collector && dart run bin/fetch.dart $(SITE) .searches.$(SITE).txt $(ARGS)

enrich-dry: require-collector-env ## List the listings that still need details, requests nothing
	cd collector && dart run bin/enrich.dart --dry-run

enrich: require-collector-env ## Read details of up to 15 new listings: make enrich [ARGS=--max=10]
	cd collector && dart run bin/enrich.dart $(ARGS)

# Each site runs on its own (-k): a block or limit on one does not stop the
# other, but the refresh still fails if either did.
refresh: require-collector-env ## Fetch and import both sites: make refresh [ARGS=--full]
	$(MAKE) -k refresh-standvirtual refresh-olx ARGS="$(ARGS)"

# Each site fetches the searches of the tracked models (make searches); a
# site with none is skipped. Pages and their manifest are replaced each run.
refresh-standvirtual: require-collector-env ## Standvirtual: search pages, import, new listings' details
	rm -f collector/samples/standvirtual/search/*.html collector/samples/standvirtual/search/searches.json
	$(MAKE) searches SITE=standvirtual
	@if [ -s collector/.searches.standvirtual.txt ]; then \
	  cd collector && dart run bin/fetch.dart standvirtual .searches.standvirtual.txt && cd .. && \
	  $(MAKE) collect SOURCE=standvirtual-search FILE=samples/standvirtual/search ARGS="$(ARGS)" && \
	  $(MAKE) enrich ARGS=--max=10; \
	else echo "Standvirtual: no tracked model has a Standvirtual search, skipped."; fi

refresh-olx: require-collector-env ## OLX: every page of each search, import (results hold the details)
	rm -f collector/samples/olx/search/*.html collector/samples/olx/search/searches.json
	$(MAKE) searches SITE=olx
	@if [ -s collector/.searches.olx.txt ]; then \
	  cd collector && dart run bin/fetch.dart olx .searches.olx.txt && cd .. && \
	  $(MAKE) collect SOURCE=olx-search FILE=samples/olx/search ARGS="$(ARGS)"; \
	else echo "OLX: no tracked model has an OLX search, skipped."; fi

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