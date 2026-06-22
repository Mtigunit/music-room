# ========================
# PRODUCTION MAKEFILE
# ========================

.PHONY: help
help:
	@echo Available production commands:
	@echo   make up         Start production services in background
	@echo   make down       Stop production services
	@echo   make build      Build production images
	@echo   make logs       Tail production logs
	@echo   make re         Restart production services

.PHONY: up
up:
	docker compose -f docker-compose.yml up -d
	@echo Production services started.

.PHONY: down
down:
	docker compose -f docker-compose.yml down
	@echo Production services stopped.

.PHONY: build
build:
	docker compose -f docker-compose.yml build
	@echo Production images built.

.PHONY: logs
logs:
	docker compose -f docker-compose.yml logs -f

.PHONY: re
re: down up
