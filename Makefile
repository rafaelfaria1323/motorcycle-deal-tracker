.DEFAULT_GOAL := help
.PHONY: help app-get app-run app-check app-build app-serve \
        collector-get collector-check collect-dry collect \
        db-push db-new check format clean \
        require-collector-env require-file

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

collect-dry: require-collector-env ## Preview an import, writes nothing: make collect-dry FILE=imports/x.json
	cd collector && dart run bin/collector.dart manual $(or $(FILE),samples/manual_sample.json) --dry-run

collect: require-collector-env require-file ## Import listings: make collect FILE=imports/x.json
	cd collector && dart run bin/collector.dart manual $(FILE)

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
	@test -n "$(FILE)" || (echo "Usage: make collect FILE=imports/my_listings.json"; exit 1)