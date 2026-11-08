#!/usr/bin/env bats
# T29 — README.md (functional-spec §6, §9, §10)

setup() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    README="${REPO_ROOT}/README.md"
}

@test "readme: exists" {
    [ -f "$README" ]
}

@test "readme: has the required sections" {
    local h
    for h in 'Install' 'Usage' 'Updating' 'Node service' 'Port conflicts' 'Troubleshooting' 'Files generated'; do
        grep -qE "^##+ .*${h}" "$README" || { echo "missing section: $h"; return 1; }
    done
}

@test "readme: install documents submodule add and init" {
    grep -qF 'git submodule add git@github.com:sjcrook/docker-laravel-config.git external/docker-laravel-config' "$README"
    grep -qF 'git submodule update --init --recursive' "$README"
}

@test "readme: usage documents interactive, --answers, and --force" {
    grep -qF './external/docker-laravel-config/generate.sh' "$README"
    grep -qF -- '--answers docker.answers.json' "$README"
    grep -qF -- '--force' "$README"
}

@test "readme: updating documents submodule update --remote and regenerate" {
    grep -qF 'git submodule update --remote external/docker-laravel-config' "$README"
    grep -qF 'generate.sh --answers docker.answers.json' "$README"
}

@test "readme: node service documents none, builtin and path" {
    grep -qF '`none`' "$README"
    grep -qF '`builtin`' "$README"
    grep -qiF 'path' "$README"
}

@test "readme: troubleshooting covers .new files, missing tools, bad snippet path" {
    grep -qF '.new' "$README"
    grep -qF 'jq' "$README"
    grep -qF 'nodeServiceBlock file not found' "$README"
}

@test "readme: files-generated table lists every output path (17 files)" {
    local f
    for f in \
        'docker-compose.yml' 'docker.answers.json' 'sail' \
        'docker/nginx/Dockerfile' 'docker/nginx/nginx.conf' 'docker/nginx/startup.sh' \
        'docker/nginx/logrotate/nginx' 'docker/nginx/sites/laravel.conf' \
        'docker/nginx/ssl/.gitignore' 'docker/nginx/ssl/generate-keys.sh' \
        'docker/php-fpm/Dockerfile' 'docker/php-fpm/laravel.ini' \
        'docker/php-fpm/php-fpm-pool.conf' 'docker/php-fpm/docker-entrypoint.sh' \
        'docker/logs/nginx/.gitkeep' 'docker/logs/php-fpm/.gitkeep' \
        '.gitignore'; do
        grep -qF "| \`${f}\`" "$README" || { echo "missing table row: $f"; return 1; }
    done
}
