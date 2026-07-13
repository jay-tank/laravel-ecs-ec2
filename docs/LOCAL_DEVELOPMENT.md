# Local Development

This guide gets the full stack — Laravel app, Nginx, MySQL, and Redis —
running on your machine with Docker Compose.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Docker Compose v2
  (`docker compose version`)
- Git

## 1. Clone and configure

```bash
git clone <your-fork-url>
cd laravel-ecs-ec2
cp .env.example .env
```

The Compose file injects sensible container defaults (`DB_HOST=db`,
`REDIS_HOST=redis`, Redis-backed sessions/cache), so `.env` works out of the
box for local development.

## 2. Build and start

```bash
docker compose up -d --build
```

This starts four services:

| Service     | Container      | Purpose                        | Host port |
| :---------- | :------------- | :----------------------------- | :-------- |
| `app`       | `laravel-app`  | PHP-FPM application runtime     | —         |
| `webserver` | `laravel-nginx`| Nginx reverse proxy             | `8080`    |
| `db`        | `laravel-db`   | MySQL 8 database                | `3306`    |
| `redis`     | `laravel-redis`| Redis cache / session store     | `6379`    |

## 3. Initialize the application

```bash
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate
```

Visit **http://localhost:8080** and hit **http://localhost:8080/health** to
confirm the proxy layer.

## Common commands

A [`Makefile`](../Makefile) wraps the most frequent tasks:

```bash
make up          # build + start the stack in the background
make down        # stop and remove containers
make logs        # tail logs from all services
make shell       # open a shell in the app container
make artisan cmd="migrate:fresh --seed"
make test        # run the PHPUnit test suite
```

Equivalent raw commands:

```bash
docker compose exec app php artisan <command>
docker compose exec app ./vendor/bin/phpunit
docker compose logs -f
```

## How the pieces connect locally

- Nginx (`config/nginx/conf.d/app.conf`) proxies PHP requests to the app
  container via `fastcgi_pass app:9000` — `app` resolves over the Compose
  network.
- PHP runtime tuning (upload size, memory limit) lives in
  `config/php/local.ini` and is mounted into the app container.
- Source code is bind-mounted into both containers, so edits are reflected
  immediately without rebuilding.

## Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| `502 Bad Gateway` | The app container isn't ready yet — `docker compose logs app`. |
| `SQLSTATE[HY000] [2002]` | Wait for MySQL to finish initializing, then retry the migration. |
| `No application encryption key` | Run `docker compose exec app php artisan key:generate`. |
| Port `8080` already in use | Set `APP_PORT` in `.env` to a free port and re-run `make up`. |
| Permission errors on `storage/` | `docker compose exec app chmod -R 775 storage bootstrap/cache`. |

## Tearing down

```bash
docker compose down          # keep the database volume
docker compose down -v       # also delete the MySQL data volume
```
