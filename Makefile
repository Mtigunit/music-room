# ========================
# CONFIG
# ========================

MOBILE_DIR=mobile
BACKEND_DIR=backend

# ANSI colors for readable terminal output
COLOR_INFO=\033[1;36m
COLOR_SUCCESS=\033[1;32m
COLOR_WARN=\033[1;33m
COLOR_CMD=\033[1;34m
COLOR_RESET=\033[0m

# ========================
# GENERAL
# ========================

.PHONY: help
help:
	@printf "%b\n" "$(COLOR_INFO)Available commands:$(COLOR_RESET)"
	@printf "%b\n" "  $(COLOR_CMD)make install$(COLOR_RESET)         Install all dependencies"
	@printf "%b\n" "  $(COLOR_CMD)make install-mobile$(COLOR_RESET)  Install mobile dependencies"
	@printf "%b\n" "  $(COLOR_CMD)make install-backend$(COLOR_RESET) Install backend dependencies"
	@printf "%b\n" "  $(COLOR_CMD)make mobile$(COLOR_RESET)          Run Flutter app"
	@printf "%b\n" "  $(COLOR_CMD)make backend$(COLOR_RESET)         Run backend"
	@printf "%b\n" "  $(COLOR_CMD)make lint$(COLOR_RESET)            Run all linters"
	@printf "%b\n" "  $(COLOR_CMD)make mobile-lint$(COLOR_RESET)     Run Flutter linter"
	@printf "%b\n" "  $(COLOR_CMD)make backend-lint$(COLOR_RESET)    Run backend linter"
	@printf "%b\n" "  $(COLOR_CMD)make format$(COLOR_RESET)          Format code"
	@printf "%b\n" "  $(COLOR_CMD)make mobile-format$(COLOR_RESET)   Format Flutter code"
	@printf "%b\n" "  $(COLOR_CMD)make backend-format$(COLOR_RESET)  Format backend code"
	@printf "%b\n" "  $(COLOR_CMD)make test$(COLOR_RESET)            Run all tests"
	@printf "%b\n" "  $(COLOR_CMD)make mobile-test$(COLOR_RESET)     Run Flutter tests"
	@printf "%b\n" "  $(COLOR_CMD)make backend-test$(COLOR_RESET)    Run backend tests"
	@printf "%b\n" "  $(COLOR_CMD)make ci$(COLOR_RESET)              Run full CI locally"
	@printf "%b\n" "  $(COLOR_CMD)make clean$(COLOR_RESET)           Clean build files"

# ========================
# INSTALL
# ========================

.PHONY: install
install:
	@printf "%b\n" "$(COLOR_INFO)Installing mobile dependencies...$(COLOR_RESET)"
	cd $(MOBILE_DIR) && flutter pub get
	@if [ -f $(BACKEND_DIR)/package.json ]; then \
		printf "%b\\n" "$(COLOR_INFO)Installing backend dependencies...$(COLOR_RESET)"; \
		cd $(BACKEND_DIR) && npm install; \
	else \
		printf "%b\\n" "$(COLOR_WARN)No backend setup yet$(COLOR_RESET)"; \
	fi
	@printf "%b\n" "$(COLOR_SUCCESS)Done: install target completed (mobile + backend dependencies checked).$(COLOR_RESET)"

.PHONY: install-mobile
install-mobile:
	cd $(MOBILE_DIR) && flutter pub get
	@printf "%b\n" "$(COLOR_SUCCESS)Done: mobile dependencies installed.$(COLOR_RESET)"

.PHONY: install-backend
install-backend:
	@if [ -f $(BACKEND_DIR)/package.json ]; then \
		cd $(BACKEND_DIR) && npm install; \
	else \
		printf "%b\\n" "$(COLOR_WARN)No backend setup yet$(COLOR_RESET)"; \
	fi
	@printf "%b\n" "$(COLOR_SUCCESS)Done: backend dependency install check completed.$(COLOR_RESET)"


# ========================
# MOBILE
# ========================

.PHONY: mobile
mobile:
	cd $(MOBILE_DIR) && flutter run
	@printf "%b\n" "$(COLOR_SUCCESS)Done: mobile run command finished.$(COLOR_RESET)"

.PHONY: mobile-lint
mobile-lint:
	cd $(MOBILE_DIR) && flutter analyze
	@printf "%b\n" "$(COLOR_SUCCESS)Done: mobile lint completed.$(COLOR_RESET)"

.PHONY: mobile-format
mobile-format:
	cd $(MOBILE_DIR) && dart format .
	@printf "%b\n" "$(COLOR_SUCCESS)Done: mobile format completed.$(COLOR_RESET)"

.PHONY: mobile-test
mobile-test:
	cd $(MOBILE_DIR) && flutter test
	@printf "%b\n" "$(COLOR_SUCCESS)Done: mobile tests completed.$(COLOR_RESET)"

.PHONY: mobile-check-format
mobile-check-format:
	cd $(MOBILE_DIR) && dart format --output=none --set-exit-if-changed .
	@printf "%b\n" "$(COLOR_SUCCESS)Done: mobile format check completed (no changes required).$(COLOR_RESET)"

.PHONY: mobile-lockfile
mobile-lockfile:
	cd $(MOBILE_DIR) && flutter pub get --enforce-lockfile
	cd $(MOBILE_DIR) && git diff --exit-code -- pubspec.lock
	@printf "%b\n" "$(COLOR_SUCCESS)Done: lockfile verification completed.$(COLOR_RESET)"

# ========================
# BACKEND
# ========================

.PHONY: backend
backend: docker-up
	@if [ -f $(BACKEND_DIR)/package.json ]; then \
		cd $(BACKEND_DIR) && npm run start:dev; \
	else \
		printf "%b\\n" "$(COLOR_WARN)No backend yet$(COLOR_RESET)"; \
	fi
	@printf "%b\n" "$(COLOR_SUCCESS)Done: backend run command check completed.$(COLOR_RESET)"

.PHONY: backend-lint
backend-lint:
	@if [ -f $(BACKEND_DIR)/package.json ]; then \
		cd $(BACKEND_DIR) && npm run lint; \
	else \
		printf "%b\\n" "$(COLOR_WARN)No backend lint$(COLOR_RESET)"; \
	fi
	@printf "%b\n" "$(COLOR_SUCCESS)Done: backend lint check completed.$(COLOR_RESET)"

.PHONY: backend-test
backend-test:
	@if [ -f $(BACKEND_DIR)/package.json ]; then \
		cd $(BACKEND_DIR) && npm run test; \
	else \
		printf "%b\\n" "$(COLOR_WARN)No backend tests$(COLOR_RESET)"; \
	fi
	@printf "%b\n" "$(COLOR_SUCCESS)Done: backend test check completed.$(COLOR_RESET)"

.PHONY: backend-format
backend-format:
	@if [ -f $(BACKEND_DIR)/package.json ]; then \
		cd $(BACKEND_DIR) && npm run format; \
	else \
		printf "%b\\n" "$(COLOR_WARN)No backend format$(COLOR_RESET)"; \
	fi
	@printf "%b\n" "$(COLOR_SUCCESS)Done: backend format check completed.$(COLOR_RESET)"

# ========================
# DOCKER COMPOSE (ROOT)
# ========================

.PHONY: docker-build
docker-build:
	docker compose -f docker-compose.yml build
	@printf "%b\n" "$(COLOR_SUCCESS)Done: docker-compose build completed.$(COLOR_RESET)"

.PHONY: docker-up
docker-up:
	docker compose -f docker-compose.yml up -d
	@printf "%b\n" "$(COLOR_SUCCESS)Done: docker-compose up completed.$(COLOR_RESET)"

.PHONY: docker-down
docker-down:
	docker compose -f docker-compose.yml down
	@printf "%b\n" "$(COLOR_SUCCESS)Done: docker-compose down completed.$(COLOR_RESET)"

.PHONY: docker-logs
docker-logs:
	docker compose -f docker-compose.yml logs -f
	@printf "%b\n" "$(COLOR_SUCCESS)Done: docker-compose logs streaming.$(COLOR_RESET)"

.PHONY: docker-backend-logs
docker-backend-logs:
	docker compose -f docker-compose.yml logs -f backend
	@printf "%b\n" "$(COLOR_SUCCESS)Done: backend logs (docker-compose) streaming.$(COLOR_RESET)"

# ========================
# GLOBAL TASKS
# ========================

.PHONY: lint
lint: mobile-lint backend-lint
	@printf "%b\n" "$(COLOR_SUCCESS)Done: all lint targets completed.$(COLOR_RESET)"

.PHONY: format
format: mobile-format backend-format
	@printf "%b\n" "$(COLOR_SUCCESS)Done: all format targets completed.$(COLOR_RESET)"

.PHONY: test
test: mobile-test backend-test
	@printf "%b\n" "$(COLOR_SUCCESS)Done: all test targets completed.$(COLOR_RESET)"

# ========================
# CI (LOCAL VERSION)
# ========================

.PHONY: ci
ci: mobile-check-format mobile-lint mobile-test mobile-lockfile backend-lint backend-test
	@sh scripts/prevent-push-to-main.sh "$${GITHUB_REF_NAME:-$$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)}"
	@sh scripts/check-branch-name.sh "$${GITHUB_HEAD_REF:-$${GITHUB_REF_NAME:-$$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)}}"
	@printf "%b\n" "$(COLOR_SUCCESS)CI checks passed ✅$(COLOR_RESET)"
	@printf "%b\n" "$(COLOR_SUCCESS)Done: ci target completed successfully.$(COLOR_RESET)"

# ========================
# CLEAN
# ========================

.PHONY: clean
clean:
	cd $(MOBILE_DIR) && flutter clean
	@printf "%b\n" "$(COLOR_SUCCESS)Done: mobile build artifacts cleaned.$(COLOR_RESET)"
