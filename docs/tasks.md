# Tasks: `docker-laravel-config`

> Specs: `docs/functional-spec.md` · `docs/technical-spec.md`
>
> Each task fits in a single agent session. Dependencies are explicit.
> Acceptance criteria (AC) are precise and testable.

## Status Board

Update this table when working on or completing a task. Do not edit the task prose; only
update the Status column here.

| Task | Title | Status |
|---|---|---|
| T01 | Initialise directory structure and `.gitignore` | 🔲 Todo |
| T02 | `templates/docker/nginx/Dockerfile` | 🔲 Todo |
| T03 | `templates/docker/nginx/nginx.conf` | 🔲 Todo |
| T04 | `templates/docker/nginx/startup.sh` | 🔲 Todo |
| T05 | `templates/docker/nginx/sites/laravel.conf` | 🔲 Todo |
| T06 | `templates/docker/nginx/logrotate/nginx` | 🔲 Todo |
| T07 | `templates/docker/nginx/ssl/` files | 🔲 Todo |
| T08 | `templates/docker/php-fpm/Dockerfile` | 🔲 Todo |
| T09 | `templates/docker/php-fpm/laravel.ini` | 🔲 Todo |
| T10 | `templates/docker/php-fpm/docker-entrypoint.sh` | 🔲 Todo |
| T11 | `templates/docker-compose.yml` | 🔲 Todo |
| T12 | `templates/snippets/node-service.yml` | 🔲 Todo |
| T13 | `templates/sail` | 🔲 Todo |
| T14 | `templates/env.docker` | 🔲 Todo |
| T15 | `schema/answers.schema.json` | 🔲 Todo |
| T16 | `examples/` answer files | 🔲 Todo |
| T17 | `generate.sh` skeleton + `check_deps()` | 🔲 Todo |
| T18 | `parse_args()` + sha256 helpers | 🔲 Todo |
| T19 | `interactive_prompts()` | 🔲 Todo |
| T20 | `load_answers()` + `validate_answers()` | 🔲 Todo |
| T21 | `save_answers()` | 🔲 Todo |
| T22 | `export_tokens()` + `render_template()` | 🔲 Todo |
| T23 | `resolve_blocks()` | 🔲 Todo |
| T24 | `write_header()` + `check_hand_edit()` | 🔲 Todo |
| T25 | Staging pass + `.gitkeep` creation | 🔲 Todo |
| T26 | `commit_staged()` + file permissions | 🔲 Todo |
| T27 | `print_env_fragment()` + `print_summary()` | 🔲 Todo |
| T28 | Wire `main()` end-to-end | 🔲 Todo |
| T29 | `README.md` | 🔲 Todo |
| T30 | Smoke-test `laravel_ipty` | 🔲 Todo |
| T31 | Smoke-test `laravel_dac_formatter` | 🔲 Todo |
| T32 | Test suite (`tests/`) | 🔲 Todo |

**Status values:** `🔲 Todo` · `🔄 In Progress` · `✅ Done · YYYY-MM-DD` · `⛔ Blocked · <reason>`

**Protocol for implementing agents:**
1. When starting a task: change its status to `🔄 In Progress`
2. When the task's AC are all verified: change status to `✅ Done · YYYY-MM-DD`
3. If blocked: change status to `⛔ Blocked · <reason>` and note it in a comment below the table
4. Never edit the task prose below — only this table changes as work progresses

---

## Epics

| ID | Epic |
|---|---|
| E1 | Repo Foundation |
| E2 | Templates — nginx |
| E3 | Templates — php-fpm |
| E4 | Templates — top-level |
| E5 | Generator — core |
| E6 | Generator — answers |
| E7 | Generator — rendering |
| E8 | Generator — output |
| E9 | README |
| E10 | Verification |
| E11 | Test Suite |

---

## E1

### T01 · Initialise directory structure and `.gitignore`
**Depends on:** nothing

Create all directories and `.gitignore`. Dirs: `templates/snippets/`, `templates/docker/nginx/ssl/`, `templates/docker/nginx/logrotate/`, `templates/docker/nginx/sites/`, `templates/docker/php-fpm/`, `examples/`, `schema/`

**AC:** `find . -type d | sort` matches functional-spec §3; `.gitignore` has sections for `.DS_Store`, `*.new`, and editor swap files.

---

## E2

### T02 · `templates/docker/nginx/Dockerfile` — invariant · Spec §8.2
**Depends on:** T01

**AC:** Base `nginx:alpine`; installs `logrotate openssl bash curl`; creates `www-data` GID/UID 82; injects `php-upstream` conf, removes `default.conf`; CMD `["/bin/bash", "/opt/startup.sh"]`; no `{{TOKEN}}` placeholders.

### T03 · `templates/docker/nginx/nginx.conf` — invariant · Spec §8.2
**Depends on:** T01

**AC:** `daemon off;`; `access_log /dev/stdout; error_log /dev/stderr;`; `include /etc/nginx/sites-available/*.conf;`; no `{{TOKEN}}` placeholders.

### T04 · `templates/docker/nginx/startup.sh` — invariant · Spec §8.3 — fixes cron bug
**Depends on:** T01

**AC:** Reads `NGINX_SERVER_NAME`/`NGINX_SERVER_ALIAS` from env; generates self-signed fallback cert using those vars; runs `envsubst '${NGINX_SERVER_NAME} ${NGINX_SERVER_ALIAS}'` over all `sites-available/*.conf`; cron expression `0 */4 * * *` (not `0 0 */4 * *`); uses `crontab -l 2>/dev/null`; no `{{TOKEN}}` placeholders.

### T05 · `templates/docker/nginx/sites/laravel.conf` — invariant · Spec §8.4
**Depends on:** T01

`${NGINX_SERVER_NAME}` / `${NGINX_SERVER_ALIAS}` are substituted by `startup.sh` at container start, NOT by the generator.

**AC:** `server_name ${NGINX_SERVER_NAME} ${NGINX_SERVER_ALIAS};` (literal dollar-brace); HTTP 80 and HTTPS 443 listens; SSL at `/etc/nginx/ssl/default.crt`+`default.key`; `fastcgi_pass php-upstream;`; logs to `/var/log/nginx/laravel_*.log`; no `{{TOKEN}}` placeholders.

### T06 · `templates/docker/nginx/logrotate/nginx` — invariant
**Depends on:** T01

**AC:** Rotates `/var/log/nginx/*.log` daily; 32 rotations; compress/delaycompress; `postrotate` sends USR1 to nginx pid.

### T07 · `templates/docker/nginx/ssl/` — `.gitignore` + `generate-keys.sh` — invariant · Spec §8.5
**Depends on:** T01

**AC `.gitignore`:** Excludes `*.crt *.key *.csr *.pem`.
**AC `generate-keys.sh`:** Accepts `<domain> [alias...]`; exits 1 with usage if no domain; detects `mkcert` via `command -v`; generates `default.crt`+`default.key` in script's own dir; includes `localhost 127.0.0.1 ::1` in SANs; `chmod 644 default.key`.

---

## E3

### T08 · `templates/docker/php-fpm/Dockerfile` — templated · Spec §8.6
**Depends on:** T01 · Tokens: `{{PHP_VERSION}}` `{{PG_CLIENT_VERSION}}` `{{NODE_APT_BLOCK}}`

**AC:** `FROM php:{{PHP_VERSION}}-fpm`; Composer `COPY --from=composer:latest`; ngrok repo `bookworm`; `pkg-config` in apt; Group 1 extensions: `pdo_pgsql pgsql bcmath gmp sockets pcntl`; Group 2: `intl` and `zip` each with `configure && install`; `opcache` absent from `docker-php-ext-install`; `{{NODE_APT_BLOCK}}` in own paragraph; xdebug: `pecl config-set php_ini … && pecl install xdebug` (no `docker-php-ext-enable`); exactly three tokens.

### T09 · `templates/docker/php-fpm/laravel.ini` — templated · Spec §8.7
**Depends on:** T01 · Tokens: `{{MEMORY_LIMIT}}` `{{UPLOAD_MAX_FILESIZE}}` `{{POST_MAX_SIZE}}` `{{TIMEZONE}}`

**AC:** `date.timezone={{TIMEZONE}}`; size limits use tokens; `opcache.enable=1`; `opcache.enable_cli` absent (comment explains runtime injection); JIT block: `opcache.jit=tracing`, `opcache.jit_buffer_size=0`, comment documents production values and Xdebug incompatibility; exactly four tokens.

### T10 · `templates/docker/php-fpm/docker-entrypoint.sh` — invariant · Spec §8.8
**Depends on:** T01

**AC:** `#!/bin/bash`; conditional cron on `RUN_CRON == "yes"`; clears `/var/log/xdebug.log`; conditional xdebug enable when `XDEBUG_MODE` non-empty; appends `opcache.enable_cli=$OPCACHE_ENABLE_CLI` to `laravel.ini`; starts `sshd -D &`; ends `exec "$@"`; no tokens.

---

## E4

### T11 · `templates/docker-compose.yml` — templated · Spec §8.1
**Depends on:** T01 · Tokens: `{{HOST_HTTP_PORT}}` `{{HOST_HTTPS_PORT}}` `{{HOST_SSH_PORT}}` `{{HOST_PGADMIN_PORT}}` `{{NODE_SERVICE_BLOCK}}`

**AC:** Services `pgadmin postgres nginx php-fpm` + `{{NODE_SERVICE_BLOCK}}` on own line before `networks:`; all four host ports use tokens; `nginx` env has `NGINX_SERVER_NAME`/`NGINX_SERVER_ALIAS`; `php-fpm` has `extra_hosts: - "host.docker.internal:host-gateway"`, exposes `"{{HOST_SSH_PORT}}:22"`, env has `XDEBUG_MODE`/`RUN_CRON`/`OPCACHE_ENABLE_CLI`; pgadmin port `"{{HOST_PGADMIN_PORT}}:80"`; exactly five tokens.

### T12 · `templates/snippets/node-service.yml` — invariant · Spec §8.1
**Depends on:** T01

**AC:** `image: node:20-alpine`; `entrypoint: [""]` and `command: ["true"]`; Docker Compose `${…}` env vars; network `sail`; no tokens.

### T13 · `templates/sail` — invariant · Spec §8.9
**Depends on:** T01

**AC:** `#!/usr/bin/env bash`; `CONTAINER_NAME="$(basename "$PWD")-php-fpm-1"` (POSIX-portable, no zsh-isms); `docker exec -i -w /var/www/laravel/current "$CONTAINER_NAME" bash -c 'set -x; exec "$@"' dummy "$@"`; usage examples in comments; no tokens.

### T14 · `templates/env.docker` — internal template · Spec §6
**Depends on:** T01 — Not written to consuming project; used by `print_env_fragment()`.

**AC:** Docker env block with `{{HOST_HTTP_PORT}}`, `{{HOST_HTTPS_PORT}}`, `{{NGINX_SERVER_NAME}}`, `{{NGINX_SERVER_ALIAS}}`; static DB/PGADMIN `NOTE:` reminder; matches functional-spec §6 exactly.

### T15 · `schema/answers.schema.json` · Spec: tech §17
**Depends on:** T01

**AC:** JSON Schema draft-07; all 15 fields with types and constraints; `required: ["schemaVersion","phpVersion","pgClientVersion","domain"]`; valid JSON.

### T16 · `examples/minimal.answers.json` and `examples/full.answers.json` · Spec: tech §18
**Depends on:** T15

**AC:** Both valid JSON; `minimal` has only four required fields; `full` has all 15 with canonical defaults.

---

## E5

### T17 · `generate.sh` skeleton, `print_usage()`, `check_deps()` · Spec: tech §2, §5
**Depends on:** T01

**AC:** Executable with `#!/usr/bin/env bash`; `--help` exits 0 with usage; bash < 4 exits 1 with version and `brew install bash` hint; missing `jq` exits 1 with message and platform-specific install hints (brew / apt / Git Bash URL); `SCRIPT_DIR` resolves correctly from any working directory; `BASH_SOURCE` guard present so `main()` does not run when script is sourced by tests.

### T18 · `parse_args()` and `sha256` helpers · Spec: tech §4, §6
**Depends on:** T17

**AC:** `--answers` sets `ANSWERS_FILE`; `--out-dir` sets `OUT_DIR`; `--force` sets `FORCE=true`; unknown flag exits 1; `sha256_file()` and `sha256_string()` each return 64-char lowercase hex using the three-way fallback chain: `sha256sum` → `shasum -a 256` → `openssl dgst -sha256`; both functions work correctly on macOS, Linux, and Git Bash.

---

## E6

### T19 · `interactive_prompts()` · Spec: tech §7
**Depends on:** T18

**AC:** All 14 prompts in order; Enter accepts defaults; `domain` loops until non-empty; `phpFpmIncludeNode` stored as `true`/`false`; ports stored as integers; `nodeServiceBlock="path"` validates file exists; calls `save_answers` before returning.

### T20 · `load_answers()` and `validate_answers()` · Spec: tech §8, §9
**Depends on:** T18

**AC:** All 15 fields loaded with `// default` fallbacks; missing file exits 1; validates `phpVersion`/`domain` non-empty, `nodeServiceBlock` valid, ports 1–65535, `phpFpmIncludeNode` boolean; both example files pass.

### T21 · `save_answers()` · Spec: tech §14
**Depends on:** T18

**AC:** Writes `docker.answers.json` to `OUT_DIR`; integers and booleans emitted without quotes; valid JSON; round-trip via `load_answers` produces identical values.

---

## E7

### T22 · `export_tokens()` and `render_template()` · Spec: tech §11
**Depends on:** T20

**AC:** All 10 scalar tokens exported as `TOKEN_*`; `render_template src dst` uses `perl -0777 -pe` to replace all `{{TOKEN}}` placeholders; empty token collapses blank lines (no triple-blank sequences); special characters including `/`, `&`, and embedded newlines in values pass through without corruption; no python3 dependency.

### T23 · `resolve_blocks()` · Spec: tech §10
**Depends on:** T22

**AC:** `nodeServiceBlock="none"` → `TOKEN_NODE_SERVICE_BLOCK=""`; `"builtin"` → content of `templates/snippets/node-service.yml`; custom path → content of that file. `phpFpmIncludeNode=false` → empty; `=true` → `apt-get install nodejs npm` RUN line.

---

## E8

### T24 · `write_header()` and `check_hand_edit()` · Spec: tech §12
**Depends on:** T22

**AC:** Header prepended with SHA-256 hash of content below it; `check_hand_edit` returns 0 on match; writes `.new` and returns 1 on mismatch with `FORCE=false`; returns 0 with `FORCE=true`; returns 0 for new files.

### T25 · `copy_invariant()`, full staging pass, `.gitkeep` creation
**Depends on:** T23, T24

Wire: render templates → write headers → copy invariants → touch `.gitkeep` files.

**AC:** `STAGE_DIR` contains all output files from functional-spec §6; rendered files have two-line header; invariant files have no header; `.gitkeep` files exist and are empty.

### T26 · `commit_staged()` and file permissions · Spec: tech §13
**Depends on:** T25

**AC:** All staged files at correct paths in `OUT_DIR`; `sail`, `generate-keys.sh`, `startup.sh`, `docker-entrypoint.sh` are `chmod +x`; hand-edited generated files → `.new` sibling, original untouched; `--force` always overwrites; invariant files always overwrite.

### T27 · `print_env_fragment()` and `print_summary()` · Spec: tech §15
**Depends on:** T25

**AC:** Env block output with correct values; DB/PGADMIN `NOTE:` reminder printed after; summary lists every file written.

### T28 · Wire `main()` — full end-to-end · Spec: tech §16
**Depends on:** T26, T27

**AC:** `./generate.sh --answers examples/full.answers.json --out-dir /tmp/test-out` exits 0; all 15 output paths present; `docker.answers.json` valid JSON matching input; generated files have header, invariant files do not; env fragment and reminder printed to stdout.

---

## E9

### T29 · Write `README.md`
**Depends on:** T28

**AC:** Sections: Install (submodule add + init); Usage (interactive, `--answers`, `--force`); Updating (`submodule update --remote` + regenerate); Node service (none/builtin/path); Port conflicts; Troubleshooting table (`.new` files, missing tools, bad snippet path); Files generated table matching functional-spec §6.

---

## E10

### T30 · Smoke-test against `laravel_ipty`
**Depends on:** T28

**AC:** Generator exits 0; all output files present; every diff against existing files is a documented intentional improvement from functional-spec §8; `docker compose up -d` succeeds and nginx serves HTTP 200/301.

### T31 · Smoke-test against `laravel_dac_formatter`
**Depends on:** T28

**AC:** Generator exits 0 with `phpFpmIncludeNode: true`; rendered `Dockerfile` contains `nodejs npm` line; every diff documented as known improvement; `docker compose up -d` succeeds.

---

## E11

### T32 · Write test suite (`tests/`) · Spec: tech §20
**Depends on:** T28

Create the full `bats-core` test suite as specified in technical-spec §20. All test files
are written to the `tests/` directory. `generate.sh` must first be updated to add the
`BASH_SOURCE` guard (tech §20) so functions can be sourced without running `main()`.

Files to create:
- `tests/run_tests.sh`
- `tests/helpers/common.bash`
- `tests/unit/sha256.bats`
- `tests/unit/parse_args.bats`
- `tests/unit/answers.bats`
- `tests/unit/render_template.bats`
- `tests/unit/resolve_blocks.bats`
- `tests/unit/hash_header.bats`
- `tests/integration/minimal.bats`
- `tests/integration/full.bats`
- `tests/integration/node_options.bats`
- `tests/integration/hand_edit.bats`

**AC:**
- `brew install bats-core` is the only prerequisite
- `./tests/run_tests.sh` exits 0 with all tests passing
- Unit tests source `generate.sh` without running `main()`
- Each `.bats` file covers all cases listed in tech §20 for that file
- Integration tests invoke `generate.sh` as a subprocess with a temp `OUT_DIR`
- Every test has a descriptive name matching the case it covers
- No test leaks temp files (all cleaned up in `teardown()`)
