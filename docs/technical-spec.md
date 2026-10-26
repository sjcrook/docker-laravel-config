# Technical Specification: `docker-laravel-config`

> Companion to `docs/functional-spec.md`. That document describes *what* the system does;
> this document describes *how* to build it — precise data formats, algorithms, tool
> choices, function signatures, and file content.

---

## 1. Dependencies

| Tool | Min version | Availability | Purpose | Check |
|---|---|---|---|---|
| `bash` | 4.0 | macOS: `brew install bash`; Linux/WSL/Git Bash: built-in | Script runtime (`declare -A` requires bash 4+) | `bash --version` |
| `jq` | 1.6 | macOS: `brew install jq`; Linux: `apt install jq`; Git Bash: manual | JSON parsing, field extraction, validation | `jq --version` |
| `perl` | 5.x | **Pre-installed on macOS, all Linux distros, and Git Bash** — no install needed | Token substitution and multi-line block injection | `perl --version` |
| `mktemp` | any | Pre-installed everywhere | Staging directory creation | `mktemp -d` |
| `sha256sum` / `shasum` / `openssl` | any | At least one is always present (see §6) | SHA-256 for hand-edit detection | detected at runtime |
| `git` | 2.x | Submodule operations (documented in README; not called by generator) | — | — |

`generate.sh` checks for `bash 4+` and `jq` at startup and exits with a clear error if
either requirement is unmet. `perl` is not checked because it is guaranteed to be present
on all supported platforms. SHA-256 is detected at runtime via a three-way fallback (§6).

---

## 2. `generate.sh` — Overall Structure

A **single monolithic bash script** at the repo root. No sourced library files.

```
generate.sh
│
├── Constants block        — SCRIPT_DIR, TEMPLATES_DIR, defaults
├── check_deps()           — verify bash 4+, jq present
├── sha256_file()          — portable sha256 wrapper (file)
├── sha256_string()        — portable sha256 wrapper (stdin string)
├── parse_args()           — --answers, --out-dir, --force
├── interactive_prompts()  — read answers from stdin with defaults
├── load_answers()         — read answers from JSON file via jq
├── validate_answers()     — field presence, type, range, path checks
├── resolve_blocks()       — build NODE_SERVICE_BLOCK and NODE_APT_BLOCK strings
├── render_template()      — perl token substitution for one file
├── copy_invariant()       — cp verbatim into staging directory
├── write_header()         — prepend generated-file header with content hash
├── check_hand_edit()      — compare stored hash vs current file; write .new on mismatch
├── commit_staged()        — move staging files to OUT_DIR; chmod executables
├── save_answers()         — write docker.answers.json via jq -n
├── print_env_fragment()   — emit .env block + DB/PGADMIN reminder to stdout
├── print_summary()        — list every file written
└── main()                 — top-level orchestration
```

---

## 3. Constants and Initialisation

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
SNIPPETS_DIR="${TEMPLATES_DIR}/snippets"
SCHEMA_FILE="${SCRIPT_DIR}/schema/answers.schema.json"

OUT_DIR="$(pwd)"   # overridden by --out-dir
ANSWERS_FILE=""    # overridden by --answers
FORCE=false        # overridden by --force

declare -A ANSWERS
```

---

## 4. Argument Parsing (`parse_args`)

| Flag | Argument | Effect |
|---|---|---|
| `--answers` | `<file>` | Path to existing `docker.answers.json`; skips prompts |
| `--out-dir` | `<dir>` | Output directory (default: `$(pwd)`) |
| `--force` | — | Skip hand-edit check; always overwrite generated files |

Unrecognised flags print usage and exit 1.

---

## 5. Dependency Check (`check_deps`)

```bash
check_deps() {
    # Bash 4+ is required for associative arrays (declare -A).
    # macOS ships bash 3.2; users must: brew install bash
    if (( BASH_VERSINFO[0] < 4 )); then
        echo "ERROR: bash 4.0+ required (found ${BASH_VERSION})."
        echo "  macOS: brew install bash"
        echo "  Then run: bash ./generate.sh  (or set your default shell to the brew bash)"
        exit 1
    fi

    # jq is the only tool that may be absent and must be installed manually.
    # perl is pre-installed on all supported platforms and is not checked.
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: Missing required tool: jq"
        echo "  macOS:      brew install jq"
        echo "  Linux:      apt install jq  (or equivalent)"
        echo "  Git Bash:   download from https://stedolan.github.io/jq/"
        exit 1
    fi
}
```

---

## 6. SHA-256 Helpers

Three-way fallback chain. Priority order:
1. `sha256sum` — GNU coreutils; present on Linux, WSL, and Git Bash.
2. `shasum -a 256` — Perl-based; pre-installed on every macOS since 10.5.
3. `openssl dgst -sha256` — tertiary safety net; virtually universal.
   Note: `openssl` output format is `SHA256(stdin)= <hash>` so `awk '{print $2}'` is used
   (vs `'{print $1}'` for the other two).

```bash
sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$1" | awk '{print $2}'
    else
        echo "ERROR: No SHA-256 tool found (tried sha256sum, shasum, openssl)" >&2
        exit 1
    fi
}

sha256_string() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        printf '%s' "$1" | openssl dgst -sha256 | awk '{print $2}'
    else
        echo "ERROR: No SHA-256 tool found (tried sha256sum, shasum, openssl)" >&2
        exit 1
    fi
}
```

---

## 7. Interactive Prompts (`interactive_prompts`)

Each prompt uses `read -r -p "…[default]: " value; value="${value:-default}"`.
`domain` has no default and loops until the user enters a non-empty value.

| Prompt | Default | ANSWERS key |
|---|---|---|
| PHP version | `8.5` | `phpVersion` |
| PostgreSQL client version | `18` | `pgClientVersion` |
| Primary domain | *(required)* | `domain` |
| Domain aliases (space-separated) | `""` | `domainAliases` |
| PHP memory_limit | `256M` | `memoryLimit` |
| PHP upload_max_filesize / post_max_size | `64M` | `uploadMaxFilesize` + `postMaxSize` |
| PHP timezone | `America/New_York` | `timezone` |
| Install nodejs + npm in php-fpm? [y/N] | `N` → `false` | `phpFpmIncludeNode` |
| Node service block [none/builtin/path] | `none` | `nodeServiceBlock` |
| ↳ If "path": path to YAML snippet | — | `nodeServiceBlock` (the path string) |
| Host HTTP port | `80` | `hostHttpPort` |
| Host HTTPS port | `443` | `hostHttpsPort` |
| Host SSH port | `2222` | `hostSshPort` |
| Host pgAdmin port | `8081` | `hostPgAdminPort` |

`phpFpmIncludeNode` is stored as the JSON literal `true` or `false` (no quotes).
Port fields are stored as bare integers (no quotes) so `save_answers()` emits valid JSON.

After collection `interactive_prompts()` calls `save_answers()` immediately — before any
file is written — so a partial run does not lose user input.

---

## 8. Loading Answers from File (`load_answers`)

All fields are read via `jq -r` with `// default` fallbacks for optional fields:

```bash
load_answers() {
    local file="$1"
    [[ -f "$file" ]] || { echo "ERROR: answers file not found: $file"; exit 1; }
    ANSWERS[phpVersion]=$(        jq -r '.phpVersion'               "$file")
    ANSWERS[pgClientVersion]=$(   jq -r '.pgClientVersion'          "$file")
    ANSWERS[domain]=$(            jq -r '.domain'                   "$file")
    ANSWERS[domainAliases]=$(     jq -r '.domainAliases // ""'      "$file")
    ANSWERS[memoryLimit]=$(       jq -r '.memoryLimit // "256M"'    "$file")
    ANSWERS[uploadMaxFilesize]=$( jq -r '.uploadMaxFilesize // "64M"' "$file")
    ANSWERS[postMaxSize]=$(       jq -r '.postMaxSize // "64M"'     "$file")
    ANSWERS[timezone]=$(          jq -r '.timezone // "America/New_York"' "$file")
    ANSWERS[phpFpmIncludeNode]=$( jq -r '.phpFpmIncludeNode // false' "$file")
    ANSWERS[nodeServiceBlock]=$(  jq -r '.nodeServiceBlock // "none"' "$file")
    ANSWERS[hostHttpPort]=$(      jq -r '.hostHttpPort // 80'       "$file")
    ANSWERS[hostHttpsPort]=$(     jq -r '.hostHttpsPort // 443'     "$file")
    ANSWERS[hostSshPort]=$(       jq -r '.hostSshPort // 2222'      "$file")
    ANSWERS[hostPgAdminPort]=$(   jq -r '.hostPgAdminPort // 8081'  "$file")
}
```

---

## 9. Answer Validation (`validate_answers`)

| Rule | Implementation |
|---|---|
| `phpVersion` non-empty | `[[ -n "${ANSWERS[phpVersion]}" ]]` |
| `domain` non-empty | `[[ -n "${ANSWERS[domain]}" ]]` |
| `nodeServiceBlock` is `"none"`, `"builtin"`, or existing file | `case` + `[[ -f "${OUT_DIR}/${path}" ]]` |
| Port fields are integers 1–65535 | `[[ "$v" =~ ^[0-9]+$ ]] && (( v >= 1 && v <= 65535 ))` |
| `phpFpmIncludeNode` is `true` or `false` | `[[ "$v" == "true" || "$v" == "false" ]]` |

Exit 1 with a clear human-readable message on any failure.

---

## 10. Block Resolution (`resolve_blocks`)

### `NODE_SERVICE_BLOCK`

```bash
resolve_node_service_block() {
    local mode="${ANSWERS[nodeServiceBlock]}"
    case "$mode" in
        none)    export TOKEN_NODE_SERVICE_BLOCK="" ;;
        builtin) export TOKEN_NODE_SERVICE_BLOCK="$(cat "${SNIPPETS_DIR}/node-service.yml")" ;;
        *)       export TOKEN_NODE_SERVICE_BLOCK="$(cat "${OUT_DIR}/${mode}")" ;;
    esac
}
```

### `NODE_APT_BLOCK`

```bash
resolve_node_apt_block() {
    if [[ "${ANSWERS[phpFpmIncludeNode]}" == "true" ]]; then
        export TOKEN_NODE_APT_BLOCK=$'# Install nodejs + npm\nRUN apt-get install -y --no-install-recommends nodejs npm\n'
    else
        export TOKEN_NODE_APT_BLOCK=""
    fi
}
```

---

## 11. Token Substitution Engine (`render_template`)

**Perl** is used rather than `sed` or Python 3.

- BSD `sed` (macOS default) cannot substitute multi-line strings or handle `/`, `&`, and
  newlines in replacement text without fragile escaping.
- Python 3 is not pre-installed on macOS since 12.3 and is absent from many minimal
  environments. Perl is pre-installed on macOS, every Linux distribution, and Git Bash —
  no installation required.

The caller exports each token as `TOKEN_<NAME>=<value>` before calling `render_template`.
Perl reads the whole file in slurp mode (`-0777`) so multi-line block tokens work correctly.
`\Q...\E` quotes the token name to neutralise any regex metacharacters it might contain.
`$ENV{VAR}` reads the replacement value from the environment, preserving embedded newlines.

```bash
render_template() {
    local src="$1"  # path inside TEMPLATES_DIR
    local dst="$2"  # path inside STAGE_DIR
    mkdir -p "$(dirname "$dst")"
    perl -0777 -pe '
        for my $key (keys %ENV) {
            next unless $key =~ /^TOKEN_/;
            (my $token = $key) =~ s/^TOKEN_//;
            my $value = $ENV{$key};
            s/\Q{{$token}}\E/$value/g;
        }
        # Collapse runs of >2 blank lines left by empty block tokens
        s/\n{3,}/\n\n/g;
    ' "$src" > "$dst"
}
```

All tokens exported before the first call via `export_tokens()`:

```bash
export_tokens() {
    export TOKEN_PHP_VERSION="${ANSWERS[phpVersion]}"
    export TOKEN_PG_CLIENT_VERSION="${ANSWERS[pgClientVersion]}"
    export TOKEN_MEMORY_LIMIT="${ANSWERS[memoryLimit]}"
    export TOKEN_UPLOAD_MAX_FILESIZE="${ANSWERS[uploadMaxFilesize]}"
    export TOKEN_POST_MAX_SIZE="${ANSWERS[postMaxSize]}"
    export TOKEN_TIMEZONE="${ANSWERS[timezone]}"
    export TOKEN_HOST_HTTP_PORT="${ANSWERS[hostHttpPort]}"
    export TOKEN_HOST_HTTPS_PORT="${ANSWERS[hostHttpsPort]}"
    export TOKEN_HOST_SSH_PORT="${ANSWERS[hostSshPort]}"
    export TOKEN_HOST_PGADMIN_PORT="${ANSWERS[hostPgAdminPort]}"
    # TOKEN_NODE_SERVICE_BLOCK and TOKEN_NODE_APT_BLOCK set by resolve_blocks()
}
```

---

## 12. Hash Header and Hand-Edit Detection

### Header format

Prepended to every **templated** output file after rendering. Invariant files get no header.

```
# Generated by docker-laravel-config — do not hand-edit.
# Source: docker.answers.json  Hash: <sha256-of-rendered-content>
```

The comment character is `#` for all files except `*.ini`, which use `;` (PHP 7+ rejects `#`
comments in ini files). `write_header()` picks it from the file name; `check_hand_edit()` only
reads the 64-hex hash from line 2, so it works for both.

The hash covers the rendered content *before* the header is prepended. This avoids circular
dependency — hash is computed, then the header (containing the hash) is prepended.

### `write_header()`

```bash
write_header() {
    local file="$1"
    local source_label="$2"
    local c='#'; [[ "$file" == *.ini ]] && c=';'
    local hash; hash=$(sha256_file "$file")
    local tmp; tmp=$(mktemp)
    {
        echo "${c} Generated by docker-laravel-config — do not hand-edit."
        echo "${c} Source: ${source_label}  Hash: ${hash}"
        cat "$file"
    } > "$tmp"
    mv "$tmp" "$file"
}
```

### `check_hand_edit()`

```bash
check_hand_edit() {
    local existing="$1"   # path in OUT_DIR (may not exist)
    local staged="$2"     # path in STAGE_DIR

    [[ -f "$existing" ]] || return 0  # new file — always safe

    local stored_hash
    stored_hash=$(sed -n '2p' "$existing" | grep -oE '[0-9a-f]{64}' || true)
    [[ -z "$stored_hash" ]] && return 0  # no header — not a generated file

    local current_hash
    current_hash=$(tail -n +3 "$existing" | sha256_string "$(tail -n +3 "$existing")")

    if [[ "$stored_hash" != "$current_hash" ]] && [[ "$FORCE" != "true" ]]; then
        echo "WARNING: Hand-edit detected: $(basename "$existing")"
        echo "  New version saved as ${existing}.new — diff and merge manually."
        cp "$staged" "${existing}.new"
        return 1
    fi
    return 0
}
```

---

## 13. Staging and Commit (`commit_staged`)

```bash
commit_staged() {
    local stage="$1"
    local out="$2"
    while IFS= read -r -d '' f; do
        local rel="${f#${stage}/}"
        local dest="${out}/${rel}"
        mkdir -p "$(dirname "$dest")"
        if check_hand_edit "$dest" "$f"; then
            cp "$f" "$dest"
            echo "  Wrote: ${rel}"
        fi
    done < <(find "$stage" -type f -print0)
    chmod +x "${out}/sail"                                2>/dev/null || true
    chmod +x "${out}/docker/nginx/ssl/generate-keys.sh"  2>/dev/null || true
    chmod +x "${out}/docker/nginx/startup.sh"             2>/dev/null || true
    chmod +x "${out}/docker/php-fpm/docker-entrypoint.sh" 2>/dev/null || true
}
```

---

## 14. Saving Answers (`save_answers`)

Uses `jq -n` with `--argjson` for integers and booleans so they emit without quotes:

```bash
save_answers() {
    local out="$1"
    jq -n \
      --argjson schemaVersion    1 \
      --arg     phpVersion       "${ANSWERS[phpVersion]}" \
      --argjson pgClientVersion  "${ANSWERS[pgClientVersion]}" \
      --arg     domain           "${ANSWERS[domain]}" \
      --arg     domainAliases    "${ANSWERS[domainAliases]}" \
      --arg     memoryLimit      "${ANSWERS[memoryLimit]}" \
      --arg     uploadMaxFilesize "${ANSWERS[uploadMaxFilesize]}" \
      --arg     postMaxSize      "${ANSWERS[postMaxSize]}" \
      --arg     timezone         "${ANSWERS[timezone]}" \
      --argjson phpFpmIncludeNode "${ANSWERS[phpFpmIncludeNode]}" \
      --arg     nodeServiceBlock  "${ANSWERS[nodeServiceBlock]}" \
      --argjson hostHttpPort      "${ANSWERS[hostHttpPort]}" \
      --argjson hostHttpsPort     "${ANSWERS[hostHttpsPort]}" \
      --argjson hostSshPort       "${ANSWERS[hostSshPort]}" \
      --argjson hostPgAdminPort   "${ANSWERS[hostPgAdminPort]}" \
      '{schemaVersion:$schemaVersion,phpVersion:$phpVersion,
        pgClientVersion:$pgClientVersion,domain:$domain,
        domainAliases:$domainAliases,memoryLimit:$memoryLimit,
        uploadMaxFilesize:$uploadMaxFilesize,postMaxSize:$postMaxSize,
        timezone:$timezone,phpFpmIncludeNode:$phpFpmIncludeNode,
        nodeServiceBlock:$nodeServiceBlock,hostHttpPort:$hostHttpPort,
        hostHttpsPort:$hostHttpsPort,hostSshPort:$hostSshPort,
        hostPgAdminPort:$hostPgAdminPort}' \
      > "${out}/docker.answers.json"
    echo "  Wrote: docker.answers.json"
}
```

---

## 15. `.env` Fragment Emission (`print_env_fragment`)

Values for ports, domain, and aliases come from `ANSWERS`. The DB/PGADMIN block is a
static heredoc reminder:

```bash
print_env_fragment() {
    cat <<EOF
#### DOCKER ################################################################

APP_CODE_PATH_HOST=./
APP_CODE_PATH_CONTAINER=/var/www/laravel/current
APP_CODE_CONTAINER_FLAG=:cached

##### NGINX
NGINX_HOST_HTTP_PORT=${ANSWERS[hostHttpPort]}
NGINX_HOST_HTTPS_PORT=${ANSWERS[hostHttpsPort]}
NGINX_HOST_LOG_PATH=./docker/logs/nginx/
NGINX_SITES_PATH=./docker/nginx/sites/
NGINX_SSL_PATH=./docker/nginx/ssl/
NGINX_SERVER_NAME=${ANSWERS[domain]}
NGINX_SERVER_ALIAS=${ANSWERS[domainAliases]}

PHP_FPM_HOST_LOG_PATH=./docker/logs/php-fpm/
EOF
    cat <<'EOF'
NOTE: These variables are also required in your .env (outside scope of this framework):

  DB_CONNECTION=pgsql  DB_HOST=postgres  DB_PORT=5432
  DB_DATABASE=<your_database_name>
  DB_USERNAME=<your_db_username>  DB_PASSWORD=<your_db_password>

  PGADMIN_DEFAULT_EMAIL=<your_pgadmin_email>
  PGADMIN_DEFAULT_PASSWORD=<your_pgadmin_password>
EOF
}
```

---

## 16. `main()` Orchestration Sequence

```
1.  check_deps
2.  parse_args "$@"
3.  if ANSWERS_FILE set → load_answers  else → interactive_prompts
4.  validate_answers
5.  resolve_node_service_block
6.  resolve_node_apt_block
7.  export_tokens
8.  STAGE_DIR=$(mktemp -d)
9.  render_template docker-compose.yml    → STAGE_DIR/docker-compose.yml
10. render_template php-fpm/Dockerfile    → STAGE_DIR/docker/php-fpm/Dockerfile
11. render_template php-fpm/laravel.ini   → STAGE_DIR/docker/php-fpm/laravel.ini
12. write_header on each of the 3 rendered files
13. copy_invariant all invariant files    → STAGE_DIR (preserving relative paths)
14. touch STAGE_DIR/docker/logs/nginx/.gitkeep
15. touch STAGE_DIR/docker/logs/php-fpm/.gitkeep
16. save_answers OUT_DIR
17. commit_staged STAGE_DIR OUT_DIR
18. rm -rf STAGE_DIR
19. print_env_fragment
20. print_summary
```

---

## 17. `schema/answers.schema.json`

JSON Schema draft-07. For IDE autocomplete only; `generate.sh` implements its own validation.

Key constraints:
- `schemaVersion`: `const: 1`
- `phpVersion`: `type: string`, `pattern: "^[0-9]+\\.[0-9]+(\\.[0-9]+)?$"`
- `pgClientVersion`: `type: integer`, `minimum: 14`
- `domain`: `type: string`, `minLength: 1`
- `memoryLimit` / `uploadMaxFilesize` / `postMaxSize`: `type: string`, `pattern: "^[0-9]+[MG]$"`
- `phpFpmIncludeNode`: `type: boolean`
- `nodeServiceBlock`: `type: string`
- Port fields: `type: integer`, `minimum: 1`, `maximum: 65535`
- `required`: `["schemaVersion","phpVersion","pgClientVersion","domain"]`

---

## 18. Example Answer Files

### `examples/minimal.answers.json`

```json
{
  "schemaVersion": 1,
  "phpVersion": "8.5",
  "pgClientVersion": 18,
  "domain": "myapp.local"
}
```

### `examples/full.answers.json`

```json
{
  "schemaVersion": 1,
  "phpVersion": "8.5",
  "pgClientVersion": 18,
  "domain": "myapp.com",
  "domainAliases": "www.myapp.com test.myapp.com",
  "memoryLimit": "256M",
  "uploadMaxFilesize": "64M",
  "postMaxSize": "64M",
  "timezone": "America/New_York",
  "phpFpmIncludeNode": false,
  "nodeServiceBlock": "builtin",
  "hostHttpPort": 80,
  "hostHttpsPort": 443,
  "hostSshPort": 2222,
  "hostPgAdminPort": 8081
}
```

---

## 19. Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success — all files written (`.new` files may exist if hand-edits detected) |
| `1` | Fatal — missing dependency, validation failure, file not found |

---

## 20. Test Suite

### Framework

**[bats-core](https://github.com/bats-core/bats-core)** (Bash Automated Testing System).
Install: `brew install bats-core`. TAP-compatible.

Run all tests: `./tests/run_tests.sh`
Run one suite: `bats tests/unit/sha256.bats`

### How unit tests source `generate.sh`

`generate.sh` guards `main()` with a BASH_SOURCE check so it can be sourced by tests
without triggering execution:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### `tests/helpers/common.bash`

```bash
setup() {
    TEST_OUT="$(mktemp -d)"
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    source "${REPO_ROOT}/generate.sh"
}
teardown() { rm -rf "$TEST_OUT"; }
```

### `tests/run_tests.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
command -v bats >/dev/null 2>&1 || {
    echo "ERROR: bats not found. Install: brew install bats-core"; exit 1
}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bats --tap "${SCRIPT_DIR}/unit" "${SCRIPT_DIR}/integration"
```

### Unit: `sha256.bats`

`sha256_file` returns 64-char hex · `sha256_string` returns 64-char hex · both are deterministic · `sha256_file` and `sha256_string` agree on the same content · three-way fallback: mock `sha256sum` absent → `shasum` used · mock both absent → `openssl` used · all three absent → exits 1 with error message.

### Unit: `parse_args.bats`

`--answers` sets `ANSWERS_FILE` · `--out-dir` sets `OUT_DIR` · `--force` sets `FORCE=true` · unknown flag exits 1 · correct defaults before parsing · `check_deps` exits 1 with bash version message when `BASH_VERSINFO[0] < 4` · `check_deps` exits 1 with jq install hints when `jq` is absent.

### Unit: `answers.bats`

`load_answers` reads all 15 fields · optional field defaults applied · exits 1 for missing file · `validate_answers` passes minimal file · passes full file · fails empty `domain` · fails empty `phpVersion` · fails port 0 and port 65536 · fails `phpFpmIncludeNode="yes"` · fails non-existent `nodeServiceBlock` path · `save_answers` writes valid JSON · integer fields are JSON numbers · boolean field is JSON boolean · round-trips via `load_answers`.

### Unit: `render_template.bats`

Uses `perl -0777 -pe` (no python3 dependency) · single token replaced · all 10 scalar tokens replaced · non-token content unchanged · empty token collapses blank lines (no triple-blank sequences) · slashes in value pass through · ampersands in value pass through · multi-line block token renders correctly (newlines preserved) · file with no tokens written unchanged.

### Unit: `resolve_blocks.bats`

`nodeServiceBlock=none` → empty token · `=builtin` → content of snippet file · `=custom path` → content of that file · `phpFpmIncludeNode=false` → empty `NODE_APT_BLOCK` · `=true` → token contains `apt-get install`, `nodejs`, `npm`.

### Unit: `hash_header.bats`

`write_header` prepends two lines · line 2 contains 64-char hex matching `Hash: [0-9a-f]{64}` · hash equals SHA-256 of lines 3+ · `check_hand_edit` returns 0 for new file · returns 0 for unmodified generated file · returns 1 and writes `.new` for modified file with `FORCE=false` · returns 0 with `FORCE=true`.

### Integration: `minimal.bats`

Subprocess: `./generate.sh --answers examples/minimal.answers.json --out-dir "$TEST_OUT"`

Exits 0 · all 16 output paths exist · `docker.answers.json` is valid JSON · defaults applied (`memoryLimit=256M`, default ports) · generated files have two-line header · invariant files have no header · `sail` and `generate-keys.sh` are executable · `.gitkeep` files exist and are empty · stdout contains `NGINX_SERVER_NAME=myapp.local` · stdout contains DB `NOTE:` reminder.

### Integration: `full.bats`

Subprocess: `examples/full.answers.json` (`nodeServiceBlock=builtin`, `phpFpmIncludeNode=false`)

Exits 0 · `docker-compose.yml` contains `node:20-alpine` · no triple blank lines · Dockerfile does NOT contain `nodejs apt` line · no unsubstituted `{{HOST_` tokens in any file · `FROM php:8.5-fpm` correct · `memory_limit = 256M` · `date.timezone=America/New_York` · `opcache.jit=tracing` present · `^opcache.enable_cli` absent.

### Integration: `node_options.bats`

`nodeServiceBlock=none` → no `node:20-alpine` in compose · `=builtin` → `node:20-alpine` + `entrypoint: [""]` present · `=custom path` → custom file content in compose · `=bad path` → exits 1 with path in stderr · `phpFpmIncludeNode=true` → `nodejs npm` in Dockerfile · `=false` → `nodejs` absent.

### Integration: `hand_edit.bats`

Second run, no edits → exits 0, no `*.new` files · second run after editing generated file → `.new` written, original unchanged · second run with `--force` after edit → no `.new`, original overwritten · second run on invariant file → always overwritten, no `.new`.
