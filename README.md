# docker-laravel-config

A single source of truth for the local-development Docker environment (nginx + php-fpm +
PostgreSQL + pgAdmin) used by Laravel projects. It is vendored into each project as a git
submodule and ships `generate.sh`, which produces every project-specific Docker file from a
small committed answers file (`docker.answers.json`).

Scope: local development only. Production/CI configs and the official Laravel Sail package
are out of scope (the `sail` script here is an unrelated `docker exec` wrapper).

## Prerequisites

- `bash` 4.0+ (macOS: `brew install bash`)
- `jq` 1.6+ (macOS: `brew install jq`; Linux: `apt install jq`)
- `perl` and a SHA-256 tool (`sha256sum`, `shasum` or `openssl`), normally pre-installed
- For the test suite: `bats-core` (`brew install bats-core`), plus `openssl` and `envsubst`

## Install

From the root of your Laravel project:

```bash
git submodule add <this-repo-url> external/docker-laravel-config
git submodule update --init
```

A fresh clone of a project that already uses the submodule needs
`git clone --recurse-submodules <url>` (or `git submodule update --init --recursive`).

## Usage

Run from the consuming project's root.

```bash
# Interactive (first time): answer the prompts; answers are saved to docker.answers.json
./external/docker-laravel-config/generate.sh

# Non-interactive / reproducible: load answers from an existing file
./external/docker-laravel-config/generate.sh --answers docker.answers.json

# Write somewhere other than the current directory (the directory is created if it doesn't exist)
./external/docker-laravel-config/generate.sh --answers docker.answers.json --out-dir /path/to/project

# Overwrite generated files even if hand-edits are detected
./external/docker-laravel-config/generate.sh --answers docker.answers.json --force
```

After generation:

1. Append the printed `.env` block to your project's `.env`, and fill in the `DB_*` and
   `PGADMIN_*` values from the `NOTE:` reminder.
2. Generate local SSL certs: `./docker/nginx/ssl/generate-keys.sh <domain> [alias ...]` (needs `mkcert`).
3. Start the stack: `docker compose up -d`.
4. Run commands in the php-fpm container with `./sail php artisan migrate`, `./sail composer require ...`.

Commit `docker.answers.json`, `docker-compose.yml`, `sail`, `docker/` and the submodule pointer.

## Updating

```bash
git submodule update --remote external/docker-laravel-config
git add external/docker-laravel-config
git commit -m "chore: update docker-laravel-config submodule"

# Regenerate using the saved answers
./external/docker-laravel-config/generate.sh --answers docker.answers.json
```

Generated files carry a two-line header with a content hash. If you hand-edited one, the
generator leaves it untouched and writes the new version as `<file>.new`. Merge intentional
changes back into the templates, then delete the `.new` files (or re-run with `--force`).
Invariant files (no header) are always overwritten.

## Node service

The `nodeServiceBlock` answer controls an optional one-shot `node` service in `docker-compose.yml`:

| Value | Effect |
|---|---|
| `none` (default) | No node service |
| `builtin` | Inserts the bundled `node:20-alpine` snippet (`templates/snippets/node-service.yml`) |
| a path | Inserts your own YAML snippet; path is relative to the project root (`--out-dir`) and must exist |

Separately, `phpFpmIncludeNode: true` installs `nodejs` and `npm` in the php-fpm image (needed
when Composer post-install scripts call node/npm).

## Dev container / no-Docker usage

When `docker` is not available on `PATH` (e.g. inside a VS Code dev container that has no Docker socket), `sail` automatically falls back to running commands over SSH using `sshpass`. The php-fpm container already starts an SSH server on the port mapped by `PHP_FPM_HOST_SSH_PORT`, so no additional container changes are needed.

**Prerequisites**

- `sshpass` must be installed in the dev container image (add it via `dev-container-config`'s apt-packages answer).
- The dev container must have `host.docker.internal` resolving to the Docker host — this is already true for containers started with `--add-host host.docker.internal:host-gateway` (the default generated devcontainer.json).

**Credentials**

The SSH username and password are set as `generate.sh` answers (`phpFpmSshUser` / `phpFpmSshPassword`, defaulting to `devuser` / `password`). They are written to the project's `.env` file as `PHP_FPM_SSH_USER` and `PHP_FPM_SSH_PASSWORD`, and `sail` reads them from there at runtime.

> **Important:** the credentials are baked into the php-fpm image at build time (`RUN useradd … && chpasswd`). If you change them in `docker.answers.json` and re-run `generate.sh`, you must **rebuild the container** — a plain restart is not enough:
> ```bash
> docker compose build php-fpm
> docker compose up -d php-fpm
> ```

## Port conflicts

Host ports are answers: `hostHttpPort` (80), `hostHttpsPort` (443), `hostSshPort` (2222) and
`hostPgAdminPort` (8081). If another service already uses one, change the value in
`docker.answers.json` (or answer the prompt differently), re-run `generate.sh --answers
docker.answers.json`, and update the matching `NGINX_HOST_HTTP_PORT` / `NGINX_HOST_HTTPS_PORT`
values in `.env`. Ports must be integers from 1 to 65535.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `WARNING: Hand-edit detected: <file>` and a `<file>.new` appears | You edited a generated file. Merge what you want from `.new`, delete it, or re-run with `--force` |
| `ERROR: Missing required tool: jq` | Install `jq` (`brew install jq` / `apt install jq`) |
| `ERROR: bash 4.0+ required` | Install a newer bash (`brew install bash`) and run the script with it |
| `ERROR: No SHA-256 tool found` | Install one of `sha256sum`, `shasum` or `openssl` |
| `ERROR: nodeServiceBlock file not found: <path>` | The custom snippet path is wrong; it is resolved relative to the project root / `--out-dir` |
| `ERROR: answers file not found` | Check the `--answers` path |
| `ERROR: ... must be an integer between 1 and 65535` | Fix the port value in the answers file |
| `ERROR: Unknown option` | Valid flags: `--answers`, `--out-dir`, `--force`, `-h/--help` |
| `ERROR: cannot create output directory: <dir>` | `--out-dir` is created automatically (including parents), but it couldn't be: a parent path is a file, or you lack write permission. Choose a writable location |

## Files generated

Paths are relative to the output directory.

| Output path | Source | Templated? | Notes |
|---|---|---|---|
| `docker-compose.yml` | `templates/docker-compose.yml` | yes | Port tokens + optional node block |
| `docker.answers.json` | prompts or `--answers` | n/a | Commit it; re-run the generator after editing |
| `sail` | `templates/sail` | no | php-fpm exec wrapper; made executable |
| `docker/nginx/Dockerfile` | `templates/docker/nginx/Dockerfile` | no | Invariant |
| `docker/nginx/nginx.conf` | `templates/docker/nginx/nginx.conf` | no | Invariant |
| `docker/nginx/startup.sh` | `templates/docker/nginx/startup.sh` | no | Invariant; uses runtime env vars |
| `docker/nginx/logrotate/nginx` | `templates/docker/nginx/logrotate/nginx` | no | Invariant |
| `docker/nginx/sites/laravel.conf` | `templates/docker/nginx/sites/laravel.conf` | no | Invariant; `startup.sh` runs `envsubst` at container start |
| `docker/nginx/ssl/.gitignore` | `templates/docker/nginx/ssl/.gitignore` | no | Keeps certs/keys out of git |
| `docker/nginx/ssl/generate-keys.sh` | `templates/docker/nginx/ssl/generate-keys.sh` | no | Host-side mkcert wrapper |
| `docker/php-fpm/Dockerfile` | `templates/docker/php-fpm/Dockerfile` | yes | PHP/PG versions, optional node apt block |
| `docker/php-fpm/laravel.ini` | `templates/docker/php-fpm/laravel.ini` | yes | Memory, upload sizes, timezone |
| `docker/php-fpm/php-fpm-pool.conf` | `templates/docker/php-fpm/php-fpm-pool.conf` | no | Invariant; pool overrides |
| `docker/php-fpm/docker-entrypoint.sh` | `templates/docker/php-fpm/docker-entrypoint.sh` | no | Invariant |
| `docker/logs/nginx/.gitkeep` | created empty | no | Tracks the log directory |
| `docker/logs/php-fpm/.gitkeep` | created empty | no | Tracks the log directory |
| `.gitignore` | `templates/gitignore.append` | no | Appended (idempotent); ignores runtime logs and generated TLS files |

