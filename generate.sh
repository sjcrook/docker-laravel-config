#!/usr/bin/env bash
# generate.sh — generates the Docker development environment for a Laravel project
# from the canonical templates in this repo. See README.md and docs/technical-spec.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
SNIPPETS_DIR="${TEMPLATES_DIR}/snippets"
SCHEMA_FILE="${SCRIPT_DIR}/schema/answers.schema.json"

OUT_DIR="$(pwd)"   # overridden by --out-dir
ANSWERS_FILE=""    # overridden by --answers
FORCE=false        # overridden by --force

declare -gA ANSWERS   # -g: stays global when the script is sourced from inside a function (tests)

print_usage() {
    cat <<'EOF'
Usage: generate.sh [--answers <file>] [--out-dir <dir>] [--force] [--help]

Generates docker-compose.yml, the docker/ tree, sail, and docker.answers.json
for a Laravel project. Run from the consuming project's root.

Options:
  --answers <file>   Load answers from an existing docker.answers.json
                     (non-interactive). Without it, prompts are shown.
  --out-dir <dir>    Output directory (default: current directory).
  --force            Skip hand-edit detection; always overwrite generated files.
  -h, --help         Show this help and exit.
EOF
}

check_deps() {
    # Bash 4+ is required for associative arrays (declare -A).
    # macOS ships bash 3.2; users must: brew install bash
    # GENERATE_BASH_MAJOR exists only so tests can simulate an old bash.
    local bash_major="${GENERATE_BASH_MAJOR:-${BASH_VERSINFO[0]}}"
    if (( bash_major < 4 )); then
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

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --answers|--out-dir)
                if (( $# < 2 )); then
                    echo "ERROR: $1 requires a value" >&2
                    print_usage >&2
                    exit 1
                fi
                if [[ "$1" == "--answers" ]]; then ANSWERS_FILE="$2"; else OUT_DIR="$2"; fi
                shift 2
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                print_usage >&2
                exit 1
                ;;
        esac
    done
}

load_answers() {
    local file="$1"
    [[ -f "$file" ]] || { echo "ERROR: answers file not found: $file"; exit 1; }
    ANSWERS[phpVersion]=$(         jq -r '.phpVersion'                     "$file")
    ANSWERS[pgClientVersion]=$(    jq -r '.pgClientVersion'                "$file")
    ANSWERS[domain]=$(             jq -r '.domain'                         "$file")
    ANSWERS[domainAliases]=$(      jq -r '.domainAliases // ""'            "$file")
    ANSWERS[memoryLimit]=$(        jq -r '.memoryLimit // "256M"'          "$file")
    ANSWERS[uploadMaxFilesize]=$(  jq -r '.uploadMaxFilesize // "64M"'     "$file")
    ANSWERS[postMaxSize]=$(        jq -r '.postMaxSize // "64M"'           "$file")
    ANSWERS[timezone]=$(           jq -r '.timezone // "America/New_York"' "$file")
    ANSWERS[phpFpmIncludeNode]=$(  jq -r '.phpFpmIncludeNode // false'     "$file")
    ANSWERS[nodeServiceBlock]=$(   jq -r '.nodeServiceBlock // "none"'     "$file")
    ANSWERS[hostHttpPort]=$(       jq -r '.hostHttpPort // 80'             "$file")
    ANSWERS[hostHttpsPort]=$(      jq -r '.hostHttpsPort // 443'           "$file")
    ANSWERS[hostSshPort]=$(        jq -r '.hostSshPort // 2222'            "$file")
    ANSWERS[hostPgAdminPort]=$(    jq -r '.hostPgAdminPort // 8081'        "$file")
    ANSWERS[hostVitePort]=$(       jq -r '.hostVitePort // 5173'           "$file")
}

validate_answers() {
    if [[ -z "${ANSWERS[phpVersion]}" || "${ANSWERS[phpVersion]}" == "null" ]]; then
        echo "ERROR: phpVersion must not be empty"
        exit 1
    fi
    if [[ -z "${ANSWERS[domain]}" || "${ANSWERS[domain]}" == "null" ]]; then
        echo "ERROR: domain must not be empty"
        exit 1
    fi

    case "${ANSWERS[nodeServiceBlock]}" in
        none|builtin) ;;
        *)
            if [[ ! -f "${OUT_DIR}/${ANSWERS[nodeServiceBlock]}" ]]; then
                echo "ERROR: nodeServiceBlock file not found: ${ANSWERS[nodeServiceBlock]} (relative to ${OUT_DIR})"
                exit 1
            fi
            ;;
    esac

    local field v
    for field in hostHttpPort hostHttpsPort hostSshPort hostPgAdminPort hostVitePort; do
        v="${ANSWERS[$field]}"
        if ! [[ "$v" =~ ^[0-9]+$ ]] || (( 10#$v < 1 || 10#$v > 65535 )); then
            echo "ERROR: $field must be an integer between 1 and 65535 (got: $v)"
            exit 1
        fi
    done

    v="${ANSWERS[phpFpmIncludeNode]}"
    if [[ "$v" != "true" && "$v" != "false" ]]; then
        echo "ERROR: phpFpmIncludeNode must be true or false (got: $v)"
        exit 1
    fi
}

save_answers() {
    local out="$1"
    # --argjson keeps integers and booleans unquoted in the output.
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
      --arg     nodeServiceBlock "${ANSWERS[nodeServiceBlock]}" \
      --argjson hostHttpPort     "${ANSWERS[hostHttpPort]}" \
      --argjson hostHttpsPort    "${ANSWERS[hostHttpsPort]}" \
      --argjson hostSshPort      "${ANSWERS[hostSshPort]}" \
      --argjson hostPgAdminPort  "${ANSWERS[hostPgAdminPort]}" \
      --argjson hostVitePort     "${ANSWERS[hostVitePort]}" \
      '{schemaVersion:$schemaVersion,phpVersion:$phpVersion,
        pgClientVersion:$pgClientVersion,domain:$domain,
        domainAliases:$domainAliases,memoryLimit:$memoryLimit,
        uploadMaxFilesize:$uploadMaxFilesize,postMaxSize:$postMaxSize,
        timezone:$timezone,phpFpmIncludeNode:$phpFpmIncludeNode,
        nodeServiceBlock:$nodeServiceBlock,hostHttpPort:$hostHttpPort,
        hostHttpsPort:$hostHttpsPort,hostSshPort:$hostSshPort,
        hostPgAdminPort:$hostPgAdminPort,hostVitePort:$hostVitePort}' \
      > "${out}/docker.answers.json"
    echo "  Wrote: docker.answers.json"
}

# prompt_value <label> <default> — sets REPLY_VALUE; Enter accepts the default.
# Exits 1 on EOF so a closed stdin can never cause an endless loop.
prompt_value() {
    local label="$1" default="$2" value
    if ! read -r -p "${label} [${default}]: " value; then
        echo "" >&2
        echo "ERROR: unexpected end of input while prompting" >&2
        exit 1
    fi
    REPLY_VALUE="${value:-$default}"
}

# prompt_port <label> <default> — re-asks until an integer 1–65535 is given.
prompt_port() {
    while true; do
        prompt_value "$1" "$2"
        if [[ "$REPLY_VALUE" =~ ^[0-9]+$ ]] && (( 10#$REPLY_VALUE >= 1 && 10#$REPLY_VALUE <= 65535 )); then
            REPLY_VALUE=$(( 10#$REPLY_VALUE ))
            return
        fi
        echo "  Port must be an integer between 1 and 65535."
    done
}

interactive_prompts() {
    local value

    prompt_value "PHP version" "8.5";                      ANSWERS[phpVersion]="$REPLY_VALUE"
    prompt_value "PostgreSQL client version" "18";         ANSWERS[pgClientVersion]="$REPLY_VALUE"

    while true; do
        if ! read -r -p "Primary domain (e.g. myapp.com): " value; then
            echo "" >&2
            echo "ERROR: unexpected end of input while prompting" >&2
            exit 1
        fi
        [[ -n "$value" ]] && break
        echo "  Domain is required."
    done
    ANSWERS[domain]="$value"

    if ! read -r -p "Domain aliases — space-separated, may be empty []: " value; then
        echo "ERROR: unexpected end of input while prompting" >&2
        exit 1
    fi
    ANSWERS[domainAliases]="$value"

    prompt_value "PHP memory_limit" "256M";                ANSWERS[memoryLimit]="$REPLY_VALUE"
    prompt_value "PHP upload_max_filesize / post_max_size" "64M"
    ANSWERS[uploadMaxFilesize]="$REPLY_VALUE"
    ANSWERS[postMaxSize]="$REPLY_VALUE"
    prompt_value "PHP timezone" "America/New_York";        ANSWERS[timezone]="$REPLY_VALUE"

    prompt_value "Install nodejs + npm in the php-fpm container? (needed for Composer post-install scripts) [y/N]" "N"
    case "$REPLY_VALUE" in
        y|Y|yes|YES|Yes) ANSWERS[phpFpmIncludeNode]="true" ;;
        *)               ANSWERS[phpFpmIncludeNode]="false" ;;
    esac

    echo "Node service in docker-compose?"
    echo "  (none)    — omit entirely  [default]"
    echo "  (builtin) — use the bundled node:20-alpine one-shot service snippet"
    echo "  (path)    — provide a path to a custom YAML snippet file"
    while true; do
        prompt_value "Choice" "none"
        case "$REPLY_VALUE" in
            none|builtin) ANSWERS[nodeServiceBlock]="$REPLY_VALUE"; break ;;
            path)
                while true; do
                    if ! read -r -p "Path to node service YAML snippet (relative to project root): " value; then
                        echo "ERROR: unexpected end of input while prompting" >&2
                        exit 1
                    fi
                    if [[ -n "$value" && -f "${OUT_DIR}/${value}" ]]; then
                        break
                    fi
                    echo "  File not found: ${value} (relative to ${OUT_DIR})"
                done
                ANSWERS[nodeServiceBlock]="$value"
                break
                ;;
            *) echo "  Please enter none, builtin, or path." ;;
        esac
    done

    prompt_port "Host HTTP port" "80";        ANSWERS[hostHttpPort]="$REPLY_VALUE"
    prompt_port "Host HTTPS port" "443";      ANSWERS[hostHttpsPort]="$REPLY_VALUE"
    prompt_port "Host SSH port" "2222";       ANSWERS[hostSshPort]="$REPLY_VALUE"
    prompt_port "Host pgAdmin port" "8081";   ANSWERS[hostPgAdminPort]="$REPLY_VALUE"
    prompt_port "Host Vite dev server port" "5173"; ANSWERS[hostVitePort]="$REPLY_VALUE"

    # Persist immediately, before any file is generated (tech §7).
    save_answers "$OUT_DIR"
}

# export_tokens — export the 11 scalar TOKEN_* variables (tech §11).
# TOKEN_NODE_SERVICE_BLOCK / TOKEN_NODE_APT_BLOCK are set by resolve_blocks().
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
    export TOKEN_HOST_VITE_PORT="${ANSWERS[hostVitePort]}"
}

# render_template <src> <dst> — replace every {{TOKEN}} with $TOKEN_<TOKEN>.
# Values are read via %ENV so /, &, \ and newlines pass through untouched.
render_template() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    perl -0777 -pe '
        for my $key (keys %ENV) {
            next unless $key =~ /^TOKEN_/;
            (my $token = $key) =~ s/^TOKEN_//;
            my $value = $ENV{$key};
            s/\Q{{$token}}\E/$value/g;
        }
        # Collapse runs of blank lines left by empty block tokens
        s/\n{3,}/\n\n/g;
    ' "$src" > "$dst"
}

# resolve_blocks — set TOKEN_NODE_SERVICE_BLOCK and TOKEN_NODE_APT_BLOCK (tech §10).
resolve_blocks() {
    local mode="${ANSWERS[nodeServiceBlock]}"
    case "$mode" in
        none)    TOKEN_NODE_SERVICE_BLOCK="" ;;
        builtin) TOKEN_NODE_SERVICE_BLOCK="$(cat "${SNIPPETS_DIR}/node-service.yml")" ;;
        *)       TOKEN_NODE_SERVICE_BLOCK="$(cat "${OUT_DIR}/${mode}")" ;;
    esac
    export TOKEN_NODE_SERVICE_BLOCK

    if [[ "${ANSWERS[phpFpmIncludeNode]}" == "true" ]]; then
        TOKEN_NODE_APT_BLOCK=$'# Install nodejs + npm\nRUN apt-get update && \\\n    apt-get install -y --no-install-recommends nodejs npm && \\\n    rm -rf /var/lib/apt/lists/*\n'
    else
        TOKEN_NODE_APT_BLOCK=""
    fi
    export TOKEN_NODE_APT_BLOCK
}

# write_header <file> <source_label> — prepend the two-line generated header (tech §12).
# The hash covers the content as it is before the header is added.
write_header() {
    local file="$1" source_label="$2"
    local c='#'; [[ "$file" == *.ini ]] && c=';'
    local hash tmp
    hash="$(sha256_file "$file")"
    tmp="$(mktemp)"
    {
        echo "${c} Generated by docker-laravel-config — do not hand-edit."
        echo "${c} Source: ${source_label}  Hash: ${hash}"
        cat "$file"
    } > "$tmp"
    mv "$tmp" "$file"
}

# check_hand_edit <existing> <staged> — return 1 (and write <existing>.new) if the
# existing generated file was hand-edited and FORCE is not true (tech §12).
check_hand_edit() {
    local existing="$1" staged="$2"

    [[ -f "$existing" ]] || return 0   # new file — always safe

    local stored_hash
    stored_hash="$(sed -n '2p' "$existing" | grep -oE '[0-9a-f]{64}' || true)"
    [[ -z "$stored_hash" ]] && return 0   # no header — not a generated file

    # Hash the body via a temp file so trailing newlines match write_header's sha256_file.
    local body current_hash
    body="$(mktemp)"
    tail -n +3 "$existing" > "$body"
    current_hash="$(sha256_file "$body")"
    rm -f "$body"

    if [[ "$stored_hash" != "$current_hash" && "$FORCE" != "true" ]]; then
        echo "WARNING: Hand-edit detected: $(basename "$existing")"
        echo "  New version saved as ${existing}.new — diff and merge manually."
        cp "$staged" "${existing}.new"
        return 1
    fi
    return 0
}

declare -ga INVARIANT_FILES=(
    sail
    docker/nginx/Dockerfile
    docker/nginx/nginx.conf
    docker/nginx/startup.sh
    docker/nginx/logrotate/nginx
    docker/nginx/sites/laravel.conf
    docker/nginx/ssl/.gitignore
    docker/nginx/ssl/generate-keys.sh
    docker/php-fpm/php-fpm-pool.conf
    docker/php-fpm/docker-entrypoint.sh
)

declare -ga RENDERED_FILES=(
    docker-compose.yml
    docker/php-fpm/Dockerfile
    docker/php-fpm/laravel.ini
)

# copy_invariant <relpath> — cp a template verbatim into STAGE_DIR, keeping its relative path.
copy_invariant() {
    local rel="$1"
    mkdir -p "$(dirname "${STAGE_DIR}/${rel}")"
    cp -p "${TEMPLATES_DIR}/${rel}" "${STAGE_DIR}/${rel}"
}

# stage_files — build every generated file inside STAGE_DIR (tech §16 steps 9-15).
# Requires ANSWERS loaded, resolve_blocks and export_tokens already run.
# docker.answers.json is written to OUT_DIR by save_answers, not staged.
stage_files() {
    local rel
    for rel in "${RENDERED_FILES[@]}"; do
        render_template "${TEMPLATES_DIR}/${rel}" "${STAGE_DIR}/${rel}"
        write_header "${STAGE_DIR}/${rel}" "docker.answers.json"
    done
    for rel in "${INVARIANT_FILES[@]}"; do
        copy_invariant "$rel"
    done
    mkdir -p "${STAGE_DIR}/docker/logs/nginx" "${STAGE_DIR}/docker/logs/php-fpm"
    : > "${STAGE_DIR}/docker/logs/nginx/.gitkeep"
    : > "${STAGE_DIR}/docker/logs/php-fpm/.gitkeep"
}

declare -ga WRITTEN_FILES=()

# commit_staged <stage_dir> <out_dir> — move staged files into OUT_DIR (tech §13).
# Hand-edited generated files get a .new sibling (check_hand_edit) and are left untouched.
commit_staged() {
    local stage="$1" out="$2" f rel dest
    while IFS= read -r -d '' f; do
        rel="${f#"${stage}"/}"
        dest="${out}/${rel}"
        mkdir -p "$(dirname "$dest")"
        if check_hand_edit "$dest" "$f"; then
            cp "$f" "$dest"
            echo "  Wrote: ${rel}"
            WRITTEN_FILES+=("$rel")
        fi
    done < <(find "$stage" -type f -print0 | sort -z)
    chmod +x "${out}/sail"                                 2>/dev/null || true
    chmod +x "${out}/docker/nginx/ssl/generate-keys.sh"    2>/dev/null || true
    chmod +x "${out}/docker/nginx/startup.sh"              2>/dev/null || true
    chmod +x "${out}/docker/php-fpm/docker-entrypoint.sh"  2>/dev/null || true
}

# print_env_fragment — emit the Docker .env block and the DB/PGADMIN reminder
# to stdout (tech §15). Renders templates/env.docker; tokens are set in a
# subshell so nothing leaks into the caller's environment.
print_env_fragment() {
    local tmp
    tmp="$(mktemp)"
    (
        export TOKEN_HOST_HTTP_PORT="${ANSWERS[hostHttpPort]}"
        export TOKEN_HOST_HTTPS_PORT="${ANSWERS[hostHttpsPort]}"
        export TOKEN_HOST_SSH_PORT="${ANSWERS[hostSshPort]}"
        export TOKEN_HOST_PGADMIN_PORT="${ANSWERS[hostPgAdminPort]}"
        export TOKEN_HOST_VITE_PORT="${ANSWERS[hostVitePort]}"
        export TOKEN_NGINX_SERVER_NAME="${ANSWERS[domain]}"
        export TOKEN_NGINX_SERVER_ALIAS="${ANSWERS[domainAliases]}"
        render_template "${TEMPLATES_DIR}/env.docker" "$tmp"
    )
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "Add the following settings to your project's .env file:"
    echo "────────────────────────────────────────────────────────────────"
    cat "$tmp"
    echo "────────────────────────────────────────────────────────────────"
    rm -f "$tmp"
}

# append_gitignore <out_dir> — append any missing lines from templates/gitignore.append
# into <out_dir>/.gitignore (idempotent: lines already present are skipped).
append_gitignore() {
    local out="$1"
    local src="${SCRIPT_DIR}/templates/gitignore.append"
    local dest="${out}/.gitignore"
    [[ -f "$src" ]] || return 0
    touch "$dest"
    local added=0
    while IFS= read -r line; do
        if ! grep -qxF "$line" "$dest"; then
            echo "$line" >> "$dest"
            added=$((added + 1))
        fi
    done < "$src"
    if (( added > 0 )); then
        echo "  .gitignore: ${added} line(s) appended"
    fi
}

# print_summary — list every file written this run (commit_staged fills
# WRITTEN_FILES) plus docker.answers.json (written by save_answers).
print_summary() {
    local f
    echo ""
    echo "Files written to ${OUT_DIR}:"
    echo "  docker.answers.json"
    for f in "${WRITTEN_FILES[@]}"; do
        echo "  ${f}"
    done
}

main() {
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            print_usage
            exit 0
        fi
    done
    check_deps
    parse_args "$@"
    if ! mkdir -p "$OUT_DIR" 2>/dev/null; then
        echo "ERROR: cannot create output directory: $OUT_DIR" >&2
        exit 1
    fi
    WRITTEN_FILES=()
    if [[ -n "$ANSWERS_FILE" ]]; then
        load_answers "$ANSWERS_FILE"
    else
        interactive_prompts   # also saves docker.answers.json
    fi
    validate_answers
    resolve_blocks
    export_tokens
    STAGE_DIR="$(mktemp -d)"
    trap 'rm -rf "${STAGE_DIR:-}"' EXIT
    stage_files
    if [[ -n "$ANSWERS_FILE" ]]; then
        save_answers "$OUT_DIR"
    fi
    commit_staged "$STAGE_DIR" "$OUT_DIR"
    rm -rf "$STAGE_DIR"
    trap - EXIT
    append_gitignore "$OUT_DIR"
    print_env_fragment
    print_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
