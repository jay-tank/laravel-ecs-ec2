# Convenience shortcuts for the local development stack.
# Usage: make <target>   (run `make help` to list targets)

.DEFAULT_GOAL := help
COMPOSE := docker compose

.PHONY: help up down build restart logs shell artisan migrate fresh test key ps

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Build and start the full stack in the background
	$(COMPOSE) up -d --build

down: ## Stop and remove containers
	$(COMPOSE) down

build: ## Rebuild images without starting
	$(COMPOSE) build

restart: ## Restart all services
	$(COMPOSE) restart

ps: ## Show running services
	$(COMPOSE) ps

logs: ## Tail logs from all services
	$(COMPOSE) logs -f

shell: ## Open a shell in the app container
	$(COMPOSE) exec app sh

artisan: ## Run an artisan command, e.g. make artisan cmd="migrate:status"
	$(COMPOSE) exec app php artisan $(cmd)

migrate: ## Run database migrations
	$(COMPOSE) exec app php artisan migrate

fresh: ## Drop all tables and re-run migrations with seeders
	$(COMPOSE) exec app php artisan migrate:fresh --seed

key: ## Generate the application encryption key
	$(COMPOSE) exec app php artisan key:generate

test: ## Run the PHPUnit test suite
	$(COMPOSE) exec app ./vendor/bin/phpunit
