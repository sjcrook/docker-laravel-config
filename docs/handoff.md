# Handoff

_Overwritten each session — a snapshot, not a log. Permanent decisions belong in commit messages / PR descriptions, not here._
_If this file is still exactly this template, no session has run yet — start from the first 🔲 Todo row in `docs/tasks.md` instead of looking for a "Next" list here._

## State
T01–T12 are done; 126 unit tests pass (`~/.local/bin/bats tests/unit`; bats was reinstalled this session from bats-core git into `~/.local`). This session completed `docker-entrypoint.sh` (T10), `docker-compose.yml` (T11), `snippets/node-service.yml` (T12), and added the invariant `templates/docker/php-fpm/php-fpm-pool.conf`. Nothing is committed yet.

## Decisions since last session
- **T24 header comment char:** `write_header()` emits `;` for `*.ini` files, `#` otherwise; `check_hand_edit()` just reads the hash from line 2. Already reflected in technical-spec §12 and functional-spec §8.7 (T24 still has to implement and test it).
- **Pool directives moved:** `pm*` / `request_terminate_timeout` removed from `laravel.ini` into a new invariant `templates/docker/php-fpm/php-fpm-pool.conf` (`[www]`), copied by the Dockerfile to `php-fpm.d/zz-laravel.conf`. **Consequences for later tasks:** output file count is now **16**, not 15 (T25/T26/T28/T32 prose and tech §20 "15 output paths" were not edited in tasks.md per protocol — use 16; technical-spec §20 already says 16). The generator must copy `php-fpm-pool.conf` as an invariant (no header). T16 `examples/` and T29 README file table need the new row (functional-spec §6 has it).
- **Entrypoint deviation from spec's original text:** `sed -i '/^opcache\.enable_cli=/d'` runs before the append so `docker restart` doesn't accumulate duplicate lines (functional-spec §8.8 updated).
- **Compose template:** no obsolete `version:` key (references had `version: '3'`); the commented-out postgres `ports` and pgadmin master-password lines were dropped; `{{NODE_SERVICE_BLOCK}}` sits alone on its own line directly above `networks:`, so an empty block leaves a blank line that `render_template` (T22) must collapse. `node-service.yml` has no trailing blank line.
- Carried over: references are inspiration, not a source to copy (departures documented in functional-spec §8.2–§8.8); `NGINX_ETC_DIR` exists only for tests; `nginx_startup.bats` needs `openssl` + `envsubst` on the host (mention in T32/README prerequisites); extra test files (`nginx_*`, `php_fpm_templates`, `top_level_templates`) are outside the T32 list — keep or fold in.
- `docker`, `nginx`, `php`, `mkcert`, `shellcheck` are NOT available here. The php-fpm Dockerfile has never been built; unverified: the `. /etc/os-release` PGDG line, `postgresql-client-<ver>` for trixie, ngrok `bookworm` suite on trixie, `pecl config-set php_ini` + `rm -f`, the `sshd_config.d` include, and that `php-fpm.d/zz-laravel.conf` loads after `zz-docker.conf`. T030/T031 must cover this.

## Open questions
- None

## Blockers
<!-- If a blocker affects a specific task, it must ALSO be marked
     ⛔ Blocked · <reason> on that task's row in docs/tasks.md -- this section
     alone will not trigger the Stop hook's (or Cline's lifecycle hooks')
     notification. A question blocking ALL further work is still a blocker:
     mark the next task to be worked Blocked too, not just this section. -->
None

## Next (1-3 tasks)
<!-- List task IDs, e.g. "S02/T003". If a task is paused on a forward test
     dependency (see docs/tasks.md's legend), list both the paused task and
     the task it depends on together, e.g. "S02/T003 (resume after S02/T005)". -->
- [ ] S04/T013 · `templates/sail`
- [ ] S04/T014 · `templates/env.docker`
- [ ] S04/T015 · `schema/answers.schema.json`
