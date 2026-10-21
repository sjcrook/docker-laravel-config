# Functional Specification: `docker-laravel-config`

## 1. Purpose and Goals

Laravel projects in this portfolio each maintain their own copy of a Docker development
environment (nginx + php-fpm + PostgreSQL + pgAdmin). Over time these copies have diverged:
different PHP versions, different memory limits, hardcoded domain names in shell scripts,
and bug-fixes applied to one project but not back-ported to others.

`docker-laravel-config` solves this by establishing a **single source of truth** for the
canonical Docker configuration. It is vendored into each Laravel project as a **git submodule**
(the same pattern used by `sjcrook/dev-container-config`) and ships a generator that produces
all project-specific Docker files from a small answers file. Every project gets the same
up-to-date, hardened configuration, with only its genuine differences (PHP version, domain
name, memory limits, etc.) captured in a committed answers file.

### Goals

| Goal | Description |
|---|---|
| Single source of truth | All shared Docker logic lives in this repo; fixes propagate to every project via a submodule update + regenerate |
| Minimal per-project differences | Only values that are genuinely project-specific are variable; everything else is invariant |
| Reproducible generation | Running `generate.sh --answers docker.answers.json` at any time reproduces the exact same output |
| Safe to update | The generator detects hand-edits to generated files and writes a `.new` sibling rather than silently clobbering them |
| Low friction to add | Adding Docker support to a new Laravel project is a `git submodule add` + one interactive `generate.sh` run |

---

## 2. Scope

This framework covers the **local development** Docker environment only:

- `docker-compose.yml` (project root)
- The `docker/` tree (nginx, php-fpm, logs, SSL)
- The Docker-specific variables appended to the project's `.env`
- The `sail` shell script (project root) — a thin wrapper that runs commands inside the
  `php-fpm` container (e.g. `./sail php artisan migrate`, `./sail composer require …`).
  This is a hand-rolled convenience script and is **not** related to Laravel Sail (the
  official Laravel Docker package); it predates and is independent of it.
- Host port mappings for nginx, php-fpm SSH, and pgAdmin

It does **not** cover:
- Production or staging Docker/container configurations
- CI/CD pipeline configuration
- The official Laravel Sail package
- Application code, tests, or deployment scripts

---

## 3. Repository Structure

```
docker-laravel-config/
├── README.md                        # User-facing: what it is, how to install, how to use
├── generate.sh                      # The generator — interactive or answers-file driven
├── .gitignore                       # Excludes .DS_Store, *.new conflict files, editor swap files
├── docs/
│   └── functional-spec.md           # This document
├── templates/
│   ├── docker-compose.yml           # Template — tokens substituted at generation time
│   ├── env.docker                   # Template — the Docker-specific .env block (to append)
│   ├── sail                         # Invariant — the php-fpm exec wrapper script
│   ├── snippets/
│   │   └── node-service.yml         # The built-in node service YAML block (optional inclusion)
│   └── docker/
│       ├── nginx/
│       │   ├── Dockerfile           # Invariant — no substitution needed
│       │   ├── nginx.conf           # Invariant
│       │   ├── startup.sh           # Invariant — uses env vars at container runtime
│       │   ├── logrotate/
│       │   │   └── nginx            # Invariant
│       │   ├── sites/
│       │   │   └── laravel.conf     # Invariant — uses ${NGINX_SERVER_NAME}/${NGINX_SERVER_ALIAS}
│       │   └── ssl/
│       │       ├── .gitignore       # Excludes *.crt *.key *.csr *.pem from project git
│       │       └── generate-keys.sh # Host-side mkcert helper — invariant
│       └── php-fpm/
│           ├── Dockerfile           # Template — PHP_VERSION, PG_CLIENT_VERSION tokens
│           ├── laravel.ini          # Template — MEMORY_LIMIT, UPLOAD_MAX_FILESIZE, etc.
│           └── docker-entrypoint.sh # Invariant
├── examples/
│   ├── minimal.answers.json         # Bare-minimum answers (good starting point)
│   └── full.answers.json            # All fields populated (illustrates every option)
├── schema/
│   └── answers.schema.json          # JSON Schema for docker.answers.json
└── tests/
    ├── run_tests.sh                 # Entry point — checks bats installed, runs all suites
    ├── helpers/
    │   └── common.bash              # Shared setup/teardown, temp dir helpers
    ├── unit/
    │   ├── sha256.bats              # sha256_file and sha256_string
    │   ├── parse_args.bats          # CLI flag parsing
    │   ├── answers.bats             # load_answers, validate_answers, save_answers
    │   ├── render_template.bats     # export_tokens and render_template
    │   ├── resolve_blocks.bats      # node service and node apt block resolution
    │   └── hash_header.bats         # write_header and check_hand_edit
    └── integration/
        ├── minimal.bats             # End-to-end: minimal answers file
        ├── full.bats                # End-to-end: full answers, builtin node service
        ├── node_options.bats        # Node service block: none / builtin / custom path
        └── hand_edit.bats           # Hand-edit detection and --force override
```

### What "invariant" means here

An **invariant** file is copied verbatim into the consuming project — no token substitution
is performed. It is tracked in the consuming project's git so developers can see exactly what
is running, but must not be hand-edited; changes belong in this repo.

A **template** file has one or more `{{TOKEN}}` placeholders that `generate.sh` replaces with
values from the answers file before writing the output.

---

## 4. Answers File (`docker.answers.json`)

The answers file is the project-specific source of truth. It is written by `generate.sh`
(either populated from interactive prompts or loaded from an existing file) and committed to
the consuming project at `docker.answers.json` (project root, alongside `docker-compose.yml`).

### 4.1 Schema

```jsonc
{
  "schemaVersion": 1,

  // PHP-FPM image tag from Docker Hub (e.g. "8.2", "8.5")
  "phpVersion": "8.5",

  // PostgreSQL apt client version to install inside the php-fpm container
  "pgClientVersion": "18",

  // Primary domain served by nginx (for SSL cert SAN and server_name)
  "domain": "myapp.com",

  // Space-separated additional server name aliases (may be empty string)
  "domainAliases": "www.myapp.com test.myapp.com",

  // PHP memory_limit
  "memoryLimit": "256M",

  // upload_max_filesize and post_max_size (should match each other)
  "uploadMaxFilesize": "64M",
  "postMaxSize": "64M",

  // PHP timezone string for date.timezone in laravel.ini
  "timezone": "America/New_York",

  // Install nodejs and npm inside the php-fpm container.
  // Required if any Composer package runs npm/node in its post-install scripts.
  // Default false — most projects do not need this.
  "phpFpmIncludeNode": false,

  // Optional node service block for docker-compose.yml.
  // Three modes:
  //   "none"    — no node service included (default)
  //   "builtin" — use the snippet shipped in templates/snippets/node-service.yml
  //   "<path>"  — path to a custom YAML block file on the host, relative to the project root
  "nodeServiceBlock": "none",

  // Host port mappings — adjust if multiple projects run simultaneously to avoid conflicts.
  "hostHttpPort": 80,
  "hostHttpsPort": 443,
  "hostSshPort": 2222,
  "hostPgAdminPort": 8081
}
```

### 4.2 Fields Reference

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `schemaVersion` | integer | yes | `1` | Must be `1` for this version of the generator |
| `phpVersion` | string | yes | — | Docker Hub tag, e.g. `"8.2"`, `"8.5"` |
| `pgClientVersion` | integer | yes | `18` | Installs `postgresql-client-<N>` via apt |
| `domain` | string | yes | — | Primary domain; used for nginx `server_name` and SSL cert CN/SAN |
| `domainAliases` | string | no | `""` | Space-separated additional names for `server_name` and SSL SAN |
| `memoryLimit` | string | no | `"256M"` | PHP `memory_limit` |
| `uploadMaxFilesize` | string | no | `"64M"` | PHP `upload_max_filesize` |
| `postMaxSize` | string | no | `"64M"` | PHP `post_max_size` |
| `timezone` | string | no | `"America/New_York"` | PHP `date.timezone` |
| `phpFpmIncludeNode` | boolean | no | `false` | Install `nodejs` + `npm` in the `php-fpm` container via apt |
| `nodeServiceBlock` | string | no | `"none"` | `"none"`, `"builtin"`, or a host-relative path to a custom YAML snippet |
| `hostHttpPort` | integer | no | `80` | Host port mapped to nginx container port 80 |
| `hostHttpsPort` | integer | no | `443` | Host port mapped to nginx container port 443 |
| `hostSshPort` | integer | no | `2222` | Host port mapped to php-fpm container port 22 (Tinkerwell SSH) |
| `hostPgAdminPort` | integer | no | `8081` | Host port mapped to pgAdmin container port 80 |

---

## 5. Generator Script (`generate.sh`)

### 5.1 Usage

```bash
# Non-interactive: load all answers from an existing file (CI-friendly, reproducible)
./external/docker-laravel-config/generate.sh --answers docker.answers.json

# Interactive: answer prompts; answers saved to docker.answers.json automatically
./external/docker-laravel-config/generate.sh

# Override the output directory (default: project root ".")
./external/docker-laravel-config/generate.sh --answers docker.answers.json --out-dir .

# Force-overwrite even if hand-edits are detected
./external/docker-laravel-config/generate.sh --answers docker.answers.json --force
```

Run from the **consuming project's root** so relative paths resolve correctly.

### 5.2 Interactive Prompts

When run without `--answers`, `generate.sh` asks the following questions (defaults in
brackets; pressing Enter accepts the default):

```
PHP version [8.5]:
PostgreSQL client version [18]:
Primary domain (e.g. myapp.com):
Domain aliases — space-separated, may be empty []:
PHP memory_limit [256M]:
PHP upload_max_filesize / post_max_size [64M]:
PHP timezone [America/New_York]:

Install nodejs + npm in the php-fpm container? (needed for Composer post-install scripts) [y/N]:

Node service in docker-compose?
  (none)    — omit entirely  [default]
  (builtin) — use the bundled node:20-alpine one-shot service snippet
  (path)    — provide a path to a custom YAML snippet file
Choice [none]:
  > If "path" was chosen: Path to node service YAML snippet (relative to project root):

Host HTTP port  [80]:
Host HTTPS port [443]:
Host SSH port   [2222]:
Host pgAdmin port [8081]:
```

After the prompts, answers are saved as `docker.answers.json` before any files are written.

#### Node service block resolution

When `nodeServiceBlock` is `"builtin"`, `generate.sh` reads
`templates/snippets/node-service.yml` from within the submodule and inserts its content at
the `{{NODE_SERVICE_BLOCK}}` position in `docker-compose.yml`.

When `nodeServiceBlock` is a path string, `generate.sh` reads the file at that path (relative
to the project root) and inserts its content instead. The path is validated at generation
time; the generator aborts with a clear error if the file does not exist.

When `nodeServiceBlock` is `"none"` (or omitted), `{{NODE_SERVICE_BLOCK}}` is replaced with
an empty string and the resulting blank line is stripped, leaving clean YAML.

The built-in snippet (`templates/snippets/node-service.yml`) is the canonical `node:20-alpine`
one-shot service — see §8.1 for the full block and the rationale behind the no-op entrypoint
pattern.

### 5.3 Processing Steps

1. **Load answers** — from file or interactive prompts; validate against
   `schema/answers.schema.json` and abort with a clear error on any violation.
2. **Stage outputs** — render each template into a temporary staging directory using `sed`
   token substitution (`{{VARIABLE}}` syntax).
3. **Copy invariant files** — copy non-template files verbatim into the staging directory.
4. **Check for hand-edits** — for each output file that already exists in the project,
   compare its content hash against the hash stored in the previously generated file's header.
   If the hashes differ, write the new version as `<file>.new` and print a warning instead
   of overwriting.
5. **Commit staged files** — move all staged files into their final destinations.
6. **Save answers file** — write (or update) `docker.answers.json` in the output directory.
7. **Print summary** — list every file written and remind the developer to append the Docker
   env block to their `.env`.

### 5.4 Hand-Edit Safety

Generated files carry a header comment of the form:

```
# Generated by docker-laravel-config — do not hand-edit.
# Source: docker.answers.json  Hash: <sha256-of-content>
```

On each run, `generate.sh` computes the SHA-256 of the current file content (excluding the
hash line itself) and compares it with the stored hash. A mismatch means the file was edited
after generation. The `--force` flag bypasses this check and always overwrites.

---

## 6. Output Files

The following files are written into the consuming project by `generate.sh`. Paths are
relative to the **consuming project root** (i.e. `--out-dir`, which defaults to `.`).

| Output Path | Source in this repo | Templated? | Notes |
|---|---|---|---|
| `docker-compose.yml` | `templates/docker-compose.yml` | yes | Port tokens + optional node block |
| `docker.answers.json` | (from prompts or `--answers`) | n/a | Committed; re-run generator after editing |
| `sail` | `templates/sail` | no | Invariant — php-fpm exec wrapper; chmod +x applied by generator |
| `docker/nginx/Dockerfile` | `templates/docker/nginx/Dockerfile` | no | Invariant |
| `docker/nginx/nginx.conf` | `templates/docker/nginx/nginx.conf` | no | Invariant |
| `docker/nginx/startup.sh` | `templates/docker/nginx/startup.sh` | no | Invariant — uses container-runtime env vars |
| `docker/nginx/logrotate/nginx` | `templates/docker/nginx/logrotate/nginx` | no | Invariant |
| `docker/nginx/sites/laravel.conf` | `templates/docker/nginx/sites/laravel.conf` | no | Invariant — `startup.sh` does `envsubst` at container start |
| `docker/nginx/ssl/.gitignore` | `templates/docker/nginx/ssl/.gitignore` | no | Excludes cert/key files from project git |
| `docker/nginx/ssl/generate-keys.sh` | `templates/docker/nginx/ssl/generate-keys.sh` | no | Host-side mkcert wrapper |
| `docker/php-fpm/Dockerfile` | `templates/docker/php-fpm/Dockerfile` | yes | `{{PHP_VERSION}}`, `{{PG_CLIENT_VERSION}}`, `{{NODE_APT_BLOCK}}` |
| `docker/php-fpm/laravel.ini` | `templates/docker/php-fpm/laravel.ini` | yes | `{{MEMORY_LIMIT}}`, `{{UPLOAD_MAX_FILESIZE}}`, `{{POST_MAX_SIZE}}`, `{{TIMEZONE}}` |
| `docker/php-fpm/docker-entrypoint.sh` | `templates/docker/php-fpm/docker-entrypoint.sh` | no | Invariant |
| `docker/logs/nginx/.gitkeep` | (created empty) | no | Ensures log directory is tracked in git |
| `docker/logs/php-fpm/.gitkeep` | (created empty) | no | Ensures log directory is tracked in git |

Additionally, a **`.env` fragment** is printed to stdout (and optionally appended with
`--append-env`) containing the Docker-specific variables that must be present in the
project's `.env`. The values for ports, domain, and domain aliases are populated from the
answers file:

```dotenv
#### DOCKER ################################################################

APP_CODE_PATH_HOST=./
APP_CODE_PATH_CONTAINER=/var/www/laravel/current
APP_CODE_CONTAINER_FLAG=:cached

##### NGINX
NGINX_HOST_HTTP_PORT=<hostHttpPort>
NGINX_HOST_HTTPS_PORT=<hostHttpsPort>
NGINX_HOST_LOG_PATH=./docker/logs/nginx/
NGINX_SITES_PATH=./docker/nginx/sites/
NGINX_SSL_PATH=./docker/nginx/ssl/
NGINX_SERVER_NAME=<domain>
NGINX_SERVER_ALIAS=<domainAliases>

PHP_FPM_HOST_LOG_PATH=./docker/logs/php-fpm/
```

After printing the fragment, the generator also prints the following reminder:

```
NOTE: The following variables are required in your .env but are outside the scope of
this framework. Ensure they are set correctly for your project:

  DB_CONNECTION=pgsql
  DB_HOST=postgres
  DB_PORT=5432
  DB_DATABASE=<your_database_name>
  DB_USERNAME=<your_db_username>
  DB_PASSWORD=<your_db_password>

  PGADMIN_DEFAULT_EMAIL=<your_pgadmin_email>
  PGADMIN_DEFAULT_PASSWORD=<your_pgadmin_password>
```

---

## 7. Template Variables Reference

| Token | Used in | Source field | Example / Notes |
|---|---|---|---|
| `{{PHP_VERSION}}` | `php-fpm/Dockerfile` | `phpVersion` | `8.5` |
| `{{PG_CLIENT_VERSION}}` | `php-fpm/Dockerfile` | `pgClientVersion` | `18` |
| `{{NODE_APT_BLOCK}}` | `php-fpm/Dockerfile` | `phpFpmIncludeNode` | `RUN apt-get install -y nodejs npm` or empty string |
| `{{MEMORY_LIMIT}}` | `php-fpm/laravel.ini` | `memoryLimit` | `256M` |
| `{{UPLOAD_MAX_FILESIZE}}` | `php-fpm/laravel.ini` | `uploadMaxFilesize` | `64M` |
| `{{POST_MAX_SIZE}}` | `php-fpm/laravel.ini` | `postMaxSize` | `64M` |
| `{{TIMEZONE}}` | `php-fpm/laravel.ini` | `timezone` | `America/New_York` |
| `{{HOST_HTTP_PORT}}` | `docker-compose.yml` | `hostHttpPort` | `80` |
| `{{HOST_HTTPS_PORT}}` | `docker-compose.yml` | `hostHttpsPort` | `443` |
| `{{HOST_SSH_PORT}}` | `docker-compose.yml` | `hostSshPort` | `2222` |
| `{{HOST_PGADMIN_PORT}}` | `docker-compose.yml` | `hostPgAdminPort` | `8081` |
| `{{NODE_SERVICE_BLOCK}}` | `docker-compose.yml` | `nodeServiceBlock` | Content of snippet file, or empty string |

---

## 8. Canonical Template Content

This section records the definitive state of each template, established from the `laravel_ipty`
project (the more up-to-date reference) with improvements from `laravel_dac_formatter` where
that project is ahead. Divergences are noted so existing projects know exactly what to migrate.

### 8.1 `docker-compose.yml`

**Canonical structure:**

- Services: `pgadmin`, `postgres`, `nginx`, `php-fpm`, optionally `node`
- All host-side port mappings use template tokens (`{{HOST_HTTP_PORT}}`, `{{HOST_HTTPS_PORT}}`,
  `{{HOST_SSH_PORT}}`, `{{HOST_PGADMIN_PORT}}`), substituted from the answers file at
  generation time. The defaults match current projects; override in `docker.answers.json`
  when running multiple projects simultaneously.
- The `nginx` service passes `NGINX_SERVER_NAME` and `NGINX_SERVER_ALIAS` as container
  environment variables so `startup.sh` can use them at start for cert generation and `envsubst`
- The `php-fpm` service includes `extra_hosts: - "host.docker.internal:host-gateway"` (required
  on Linux for Xdebug to reach the host IDE; harmless on macOS)
- The `php-fpm` service exposes `{{HOST_SSH_PORT}}:22` for Tinkerwell SSH access
- The optional `node` service block is the canonical `node:20-alpine` one-shot pattern:

```yaml
    node:
        image: node:20-alpine
        working_dir: ${APP_CODE_PATH_CONTAINER}
        volumes:
            - ${APP_CODE_PATH_HOST}:${APP_CODE_PATH_CONTAINER}${APP_CODE_CONTAINER_FLAG}
        networks:
            - sail
        # Run a no-op by default so the container exits cleanly when used with
        # `docker compose run --rm node npm run build` etc.
        entrypoint: [""]
        command: ["true"]
```

  The `entrypoint: [""]` + `command: ["true"]` pattern overrides the `node:alpine` image's
  default interactive REPL entrypoint. The container starts and immediately exits, so
  `docker compose up` does not leave a hanging process. Invoke on demand:
  `docker compose run --rm node npm run build`.

  This block is stored verbatim in `templates/snippets/node-service.yml` and is included
  only when `nodeServiceBlock` is `"builtin"` or a custom path.

**Known divergence in `laravel_dac_formatter`:** missing `node` service; missing `extra_hosts`
on `php-fpm`; missing `NGINX_SERVER_NAME`/`NGINX_SERVER_ALIAS` env vars on `nginx`; all port
mappings are hardcoded rather than token-driven.

### 8.2 `docker/nginx/Dockerfile`

Identical between both projects. Canonical content is current. Key characteristics:

- Base image: `nginx:alpine`
- Installs: `logrotate`, `openssl`, `bash`, `curl`
- Creates `www-data` group/user (GID/UID 82)
- Injects upstream `php-upstream` conf and removes default conf
- Calls `startup.sh` as the CMD

### 8.3 `docker/nginx/startup.sh`

**Canonical version (from `laravel_ipty`):**

- Reads `NGINX_SERVER_NAME` and `NGINX_SERVER_ALIAS` from the container environment
- If no cert is present at `/etc/nginx/ssl/default.crt`, generates a self-signed fallback
  using those env vars (with a logged warning that this won't satisfy HSTS requirements)
- Runs `envsubst '${NGINX_SERVER_NAME} ${NGINX_SERVER_ALIAS}'` over all `*.conf` files in
  `/etc/nginx/sites-available/` — this is the mechanism that makes `laravel.conf` generic
- Sets up a cron job to reload nginx every 4 hours, starts crond, then starts nginx.
  The canonical cron expression is `0 */4 * * *` (every 4 hours). **Both existing projects
  contain the bug `0 0 */4 * *` which fires at midnight on every 4th day of the month, not
  every 4 hours.** The template fixes this:

  ```bash
  # Reload nginx every 4 hours (refreshes SSL cert handles and clears stale connections)
  (crontab -l 2>/dev/null ; echo "0 */4 * * * nginx -s reload") | crontab -
  ```

  The `2>/dev/null` suppresses the "no crontab for root" error that occurs on first run
  when no crontab exists yet.

**Note:** This cron runs inside the **nginx container** and reloads nginx only. It is entirely
separate from the Laravel scheduler cron in the `php-fpm` container (see §8.8).

**Known divergence in `laravel_dac_formatter`:** hardcodes `cryptotrends.net` in the
cert-generation block; has no `envsubst` step.

### 8.4 `docker/nginx/sites/laravel.conf`

**Canonical version:** uses `${NGINX_SERVER_NAME}` and `${NGINX_SERVER_ALIAS}` as literal
placeholder strings in the `server_name` directive. These are substituted at container start
by `startup.sh`'s `envsubst` call — **not** by `generate.sh`.

```nginx
server_name ${NGINX_SERVER_NAME} ${NGINX_SERVER_ALIAS};
```

This makes the file truly generic — `generate.sh` copies it verbatim and `startup.sh`
handles the per-project domain at runtime via the project's `.env`.

**Known divergence in `laravel_ipty`:** `laravel.conf` still has the literal domain name
`ipresenttoyou.com` in `server_name`. The `startup.sh` envsubst logic is correct but the
conf file has not yet been updated to use the placeholders. The canonical template corrects
this.

**Known divergence in `laravel_dac_formatter`:** `server_name` is hardcoded to
`cryptotrends.net`.

### 8.5 `docker/nginx/ssl/generate-keys.sh`

**Canonical version (from `laravel_ipty`):** uses `mkcert` to generate browser-trusted certs
on the macOS host. Accepts `<domain> [alias...]` as arguments. This file does not exist in
`laravel_dac_formatter`.

### 8.6 `docker/php-fpm/Dockerfile`

**Template variables:** `{{PHP_VERSION}}`, `{{PG_CLIENT_VERSION}}`, `{{NODE_APT_BLOCK}}`

**Canonical approach:**

**Composer install:** Use multi-stage copy from the official Composer image — cleaner, faster,
and avoids the `curl | php` pipe which can fail silently on network errors:

```dockerfile
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
```

**PHP extension installation — two groups:**

Extensions are split into two `RUN` groups. This isolates the `configure`-sensitive extensions
(`intl`, `zip`) for clarity and debuggability without unnecessary extra layers:

```dockerfile
# Group 1: Stable extensions — no configure step needed
RUN docker-php-ext-install pdo_pgsql pgsql bcmath gmp sockets pcntl

# Group 2: Extensions that require explicit configure
RUN docker-php-ext-configure intl && docker-php-ext-install intl
RUN docker-php-ext-configure zip  && docker-php-ext-install zip
```

`opcache` is **not** in the install list. PHP 8.x ships with OPcache bundled and pre-compiled
as a shared extension; it only needs to be enabled via `laravel.ini` (done in §8.7), not
built. Including it in `docker-php-ext-install` on PHP 8.x is a no-op at best and produces
a warning at worst.

**nodejs / npm in php-fpm (conditional):** Controlled by `{{NODE_APT_BLOCK}}`. When
`phpFpmIncludeNode` is `true`, the token is replaced with:

```dockerfile
# Install nodejs + npm (required if Composer post-install scripts invoke node/npm)
RUN apt-get install -y --no-install-recommends nodejs npm
```

When `false`, the token is replaced with an empty string. Default is `false` — the majority
of projects do not need this. Set to `true` for projects (like `laravel_dac_formatter`) where
Composer package post-install scripts invoke `node` or `npm` and must find them in the
`php-fpm` container's PATH.

**ngrok repo:** Uses `bookworm` (the Debian 12 codename matching the `php:8.x-fpm` base
image), not `buster` (Debian 10). `laravel_ipty` has the wrong codename which causes apt to
fail silently or pull incompatible binaries.

**xdebug installation:**

```dockerfile
RUN pecl config-set php_ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    pecl install xdebug
# Activation happens at container start in docker-entrypoint.sh — NOT here
```

`pecl config-set php_ini` is required on PHP 8.x because PECL cannot locate the conventional
`php.ini` path in the official Docker PHP image (which uses the `conf.d/` pattern). Without
it, `pecl install` emits a warning and may write the activation stub to the wrong location.
`docker-php-ext-enable xdebug` is deliberately **not** called at build time — xdebug is
installed (the `.so` is present) but inactive until `docker-entrypoint.sh` enables it at
container start when `XDEBUG_MODE` is set. This means a container running with
`XDEBUG_MODE=''` carries zero xdebug overhead.

**Known divergences in `laravel_ipty`:** uses the older `curl | php` composer install; uses
`buster` for the ngrok repo; installs all extensions in a single `docker-php-ext-install`
call (including `opcache`); missing `pecl config-set` before `pecl install xdebug`.

### 8.7 `docker/php-fpm/laravel.ini`

**Template variables:** `{{MEMORY_LIMIT}}`, `{{UPLOAD_MAX_FILESIZE}}`, `{{POST_MAX_SIZE}}`,
`{{TIMEZONE}}`

**Canonical content:**

```ini
date.timezone={{TIMEZONE}}
display_errors=Off
log_errors=On

; Maximum amount of memory a script may consume
memory_limit = {{MEMORY_LIMIT}}
; Maximum allowed size for uploaded files
upload_max_filesize = {{UPLOAD_MAX_FILESIZE}}
; Sets max size of post data allowed
post_max_size = {{POST_MAX_SIZE}}

pm = ondemand
pm.max_children = 5
pm.process_idle_timeout = 10s
request_terminate_timeout = 60s

; OPcache settings
opcache.enable=1
; opcache.enable_cli is intentionally NOT set here — it is injected at container
; start by docker-entrypoint.sh from the OPCACHE_ENABLE_CLI env var. See §8.8.
; The production/worker value is 1; the local dev default (via docker-compose.yml) is 0.
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
; Revalidate file timestamps every 2 seconds in local dev
opcache.validate_timestamps=1
opcache.revalidate_freq=2

; JIT Configuration
; Production values: opcache.jit=tracing, opcache.jit_buffer_size=128M
; Local dev: buffer_size=0 disables JIT compilation without removing the config,
; which also silences the "JIT disabled because Xdebug is active" warning.
; Xdebug and JIT are fundamentally incompatible — Xdebug hooks into the opcode
; execution pipeline that JIT bypasses. Setting buffer_size=0 is the standard
; local-dev workaround.
opcache.jit=tracing
opcache.jit_buffer_size=0
```

**Default limits (higher than `laravel_ipty`, aligned with `laravel_dac_formatter`):**
`memory_limit=256M`, `upload_max_filesize=64M`, `post_max_size=64M`. Adjust via the answers
file per project.

**Why `opcache.enable_cli` is absent from this file:**
The template deliberately does not set `opcache.enable_cli`. Instead, `docker-entrypoint.sh`
appends the correct value at container start from the `OPCACHE_ENABLE_CLI` environment
variable. This means the setting is a runtime toggle (change `docker-compose.yml` and
`docker compose up -d`) rather than a build-time constant. See §8.8 for the mechanism.

**Known divergences in `laravel_ipty`:** lower limits (`128M`/`20M`/`20M`); no JIT block;
`opcache.enable_cli` is commented out in the ini rather than being runtime-injected.

### 8.8 `docker/php-fpm/docker-entrypoint.sh`

**Canonical version:**

```bash
#!/bin/bash

# Start the cron service (runs the Laravel scheduler: artisan schedule:run).
# This cron is inside the php-fpm container and is entirely separate from the
# nginx reload cron in startup.sh (which runs inside the nginx container).
if [ "yes" == "${RUN_CRON}" ]; then
    echo "Starting cron"
    cron -f &
fi

rm -f /var/log/xdebug.log

# Add xdebug configuration at container start (not at build time).
# The xdebug .so is present in the image (installed by pecl in Dockerfile)
# but is not active until this block runs. A container with XDEBUG_MODE=''
# skips this block entirely — xdebug is never loaded and has zero overhead.
if [ ! -z "${XDEBUG_MODE}" ]; then
    echo "Enabling xdebug"
    docker-php-ext-enable xdebug && \
    echo "zend_extension=xdebug"                      >  /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
    echo "xdebug.mode=$XDEBUG_MODE"                   >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
    echo "xdebug.start_with_request=yes"              >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
    echo "xdebug.client_host=host.docker.internal"    >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
    echo "xdebug.log=/var/log/xdebug.log"             >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
fi

# Inject opcache.enable_cli at runtime so it can be toggled via docker-compose.yml
# without rebuilding the image. PHP processes conf.d files alphabetically and the
# last occurrence of a setting wins — appending here overrides any value in laravel.ini.
#
# OPCACHE_ENABLE_CLI=0 (default in docker-compose.yml):
#   CLI processes (artisan, Tinkerwell SSH) always see fresh files — no stale-cache issues.
#
# OPCACHE_ENABLE_CLI=1 (set in docker-compose.yml for queue worker performance testing):
#   CLI opcache enabled; do not use when interactively editing code during the same session.
echo "opcache.enable_cli=$OPCACHE_ENABLE_CLI" >> /usr/local/etc/php/conf.d/laravel.ini

# Start the SSH server so that Tinkerwell can connect.
/usr/sbin/sshd -D &

exec "$@"
```

**The `opcache.enable_cli` injection mechanism explained:**

PHP reads all `.ini` files in `conf.d/` alphabetically on every process start. Within a
single file, the last occurrence of a setting wins. `laravel.ini` intentionally omits
`opcache.enable_cli` (see §8.7). This `echo >>` appends the line at container start, making
it the definitive last value PHP sees. The result: change `OPCACHE_ENABLE_CLI` in
`docker-compose.yml` and `docker compose up -d` — no image rebuild needed.

**Known divergence in `laravel_dac_formatter`:** missing the `opcache.enable_cli` injection
line — the value is effectively fixed to whatever is in the built ini file for the lifetime
of the image.

### 8.9 `sail` (project root)

The `sail` script is a thin bash wrapper that executes commands inside the running `php-fpm`
container, working in the Laravel app directory. It is the primary way to run artisan, composer,
and other PHP CLI commands during local development without needing to `docker exec` manually.

**Canonical version:**

```bash
#!/usr/bin/env bash

# Run commands inside the php-fpm container.
# Usage examples:
#   ./sail php artisan migrate
#   ./sail php artisan tinker
#   ./sail composer require vendor/package
#   ./sail php artisan queue:work

# Derive the container name from the current directory name (Docker Compose project name).
# basename "$PWD" is POSIX-portable (works on bash, zsh, Linux, macOS, Git Bash, WSL).
CONTAINER_NAME="$(basename "$PWD")-php-fpm-1"

docker exec -i -w /var/www/laravel/current "$CONTAINER_NAME" \
  bash -c 'set -x; exec "$@"' dummy "$@"
```

**How the container name is derived:** Docker Compose names containers
`<project-name>-<service-name>-<replica>` where `<project-name>` defaults to the
lowercase name of the directory containing `docker-compose.yml`. `basename "$PWD"` is
POSIX-portable and works identically on bash, zsh, macOS, Linux, Git Bash, and WSL —
unlike the zsh-specific `${PWD:t}` expansion used in both existing projects.

**`#!/usr/bin/env bash` vs `#!/bin/zsh`:** Using `env bash` locates whichever `bash` is
first in `PATH`, meaning the Homebrew bash 4+ at `/opt/homebrew/bin/bash` is used on
macOS rather than the system bash 3.2 at `/bin/bash`. It also works on Linux and Git Bash
without modification. The original `#!/bin/zsh` shebang is not portable to Linux (zsh is
not installed by default) or Git Bash.

**The `dummy "$@"` pattern:** `bash -c '...' dummy "$@"` passes `dummy` as `$0` (the
script name inside `bash -c`) and the real arguments as `$1`, `$2`, etc. Without `dummy`,
the first argument would be consumed as `$0` and silently dropped.

**The generator** copies this script verbatim and applies `chmod +x sail` so it is
immediately executable without an extra step.

---

## 9. Project Integration

### 9.1 Adding Docker config to a new or existing Laravel project

```bash
# From the project root:

# 1. Add this repo as a submodule
git submodule add git@github.com:sjcrook/docker-laravel-config.git external/docker-laravel-config
git submodule update --init --recursive

# 2. Run the generator interactively (first time)
./external/docker-laravel-config/generate.sh

# 3. Append the printed .env block to your project's .env
#    Then fill in DB_*, PGADMIN_*, and other project-specific values

# 4. Generate mkcert SSL certs for local HTTPS
./docker/nginx/ssl/generate-keys.sh <domain> [alias1 alias2 ...]

# 5. Start the stack
docker compose up -d
```

### 9.2 Migrating an existing project

For projects that already have a hand-maintained `docker/` directory (e.g. `laravel_ipty`,
`laravel_dac_formatter`):

1. Add the submodule as above.
2. Run `generate.sh` interactively, providing the project's existing domain and settings.
3. Diff the generated files against the existing files.
4. Remove the old hand-maintained files and commit the generated ones.
5. Commit `docker.answers.json` and the `.gitmodules` update.

The existing Docker env block in `.env` is already in the correct format and needs only
the addition of `NGINX_SERVER_ALIAS` (if not present) and a review against the generated
`env.docker` fragment.

### 9.3 A fresh clone

A developer cloning a project that already uses this submodule:

```bash
git clone --recurse-submodules <project-url>
# or, if already cloned without submodules:
git submodule update --init --recursive
```

The generated files (`docker-compose.yml`, `docker/`, `docker.answers.json`) are already
committed to the consuming project — no need to re-run the generator unless changes are needed.

---

## 10. Updating the Framework

When this repo receives improvements, consuming projects pull them in and regenerate:

```bash
# From the consuming project root:
git submodule update --remote external/docker-laravel-config
git add external/docker-laravel-config
git commit -m "chore: update docker-laravel-config submodule"

# Regenerate using the saved answers file
./external/docker-laravel-config/generate.sh --answers docker.answers.json
```

The hand-edit detection (§5.4) ensures local tweaks surface as `.new` conflict files rather
than being silently lost. Review `.new` files, merge intentional local changes back into the
canonical templates, and delete the `.new` files.

---

## 11. `.gitignore` (this repo)

```gitignore
# macOS
.DS_Store

# generate.sh conflict output — hand-edit detected; see README
*.new

# Editor swap/backup files
*.swp
*.swo
*~
```

---

## 12. What Consuming Projects Must Commit

| Item | Committed to project? | Notes |
|---|---|---|
| `external/docker-laravel-config/` (submodule pointer) | yes | The commit SHA pointer, not the files themselves |
| `docker.answers.json` | yes | The authoritative per-project answers |
| `docker-compose.yml` | yes | Generated — do not hand-edit |
| `sail` | yes | Copied verbatim — do not hand-edit |
| `docker/nginx/**` | yes | Generated/copied — do not hand-edit |
| `docker/php-fpm/**` | yes | Generated/copied — do not hand-edit |
| `docker/logs/nginx/.gitkeep` | yes | Ensures the log directory exists |
| `docker/logs/php-fpm/.gitkeep` | yes | Ensures the log directory exists |
| `docker/nginx/ssl/default.crt` | **no** | Excluded by `docker/nginx/ssl/.gitignore` |
| `docker/nginx/ssl/default.key` | **no** | Excluded by `docker/nginx/ssl/.gitignore` |

---

## 13. Design Decisions and Rationale

### Why a submodule rather than a package manager?

Laravel projects are not Node or PHP packages — they have no `package.json` or `composer.json`
entry for "docker tooling". A git submodule is the lightest-weight vendoring mechanism
available, it keeps the full history of the framework visible inside each project, and it
mirrors the pattern already established by `sjcrook/dev-container-config`.

### Why generate files rather than use them directly from the submodule?

- **Visibility:** developers read `docker-compose.yml` and `Dockerfile` directly without
  navigating into `external/`. Docker, editors, and linters work without special configuration.
- **Auditability:** `git diff` against committed generated files makes any deviation from the
  canonical template immediately apparent.
- **Offline operation:** once generated, no network access or submodule presence is needed to
  build or run Docker.

### Why `{{TOKEN}}` substitution rather than `envsubst` in `generate.sh`?

`envsubst` would require every shell environment variable to be exported before running the
generator, creating interference risk with unrelated shell variables. Named `{{TOKEN}}`
placeholders are unambiguous and safe to process with `sed`. The `startup.sh` script at
container runtime still uses `envsubst` for the nginx site conf because that substitution
happens inside the container where the environment is tightly controlled.

### Why is `laravel.conf` invariant (not templated by `generate.sh`)?

The `server_name` directive uses `${NGINX_SERVER_NAME}` and `${NGINX_SERVER_ALIAS}` as
placeholders that `startup.sh` substitutes at container start via `envsubst`. The same
`laravel.conf` is correct for every project — the domain is injected at runtime from the
`.env`-sourced environment, not at generation time.

### PHP version as an answers-file variable

PHP version is the only per-project variable in `docker/php-fpm/Dockerfile`. Keeping it in
the answers file means updating a project from PHP 8.2 → 8.5 is a one-line change to
`docker.answers.json` followed by `generate.sh --answers docker.answers.json`.

### Why host ports are in the answers file

All four host-side port mappings (`hostHttpPort`, `hostHttpsPort`, `hostSshPort`,
`hostPgAdminPort`) are answer-file variables. The defaults (`80`, `443`, `2222`, `8081`)
work when only one project's Docker stack is running at a time. When two projects run
simultaneously, each project simply uses a different set of ports in its `docker.answers.json`
and regenerates. There is no need for a shared port registry or any cross-project coordination
— the answers file is the complete record of a project's port choices.

### Why the `sail` script is invariant (not templated)

The `sail` script has no project-specific values — it derives the container name from the
working directory at runtime using `basename "$PWD"`. There is therefore nothing to substitute at
generation time; the file is copied verbatim. Because it is an invariant copy (not a
hand-edited file), the generator can safely overwrite it on each update pull without the
hand-edit safety check.

---

## 14. Future Considerations

The following are out of scope for the initial implementation but noted for future work:

- **Redis service** — some projects may add Redis; an optional `includeRedisService` boolean
  could be added to the answers schema.
- **Mailpit / MailHog service** — a local mail-catching container is a common local dev need.
- **JSON Schema validation in CI** — a GitHub Actions workflow could validate
  `docker.answers.json` against `schema/answers.schema.json` on every push.
