# Planning review

Status: Approved

## Proposal (revision 6, 2026-11-08)

Change planning against the approved revision 5 snapshot. Same root cause as T036: `{{HOST_SSH_PORT}}` and `{{HOST_PGADMIN_PORT}}` are still baked in as literal integers at generation time in `templates/docker-compose.yml`. Neither `PHP_FPM_HOST_SSH_PORT` nor `PGADMIN_HOST_PORT` exists in `templates/env.docker`, so there is no way to change those ports post-generation by editing `.env`.

Fix: mirror the T036 pattern for both remaining ports. Add `PHP_FPM_HOST_SSH_PORT={{HOST_SSH_PORT}}` and `PGADMIN_HOST_PORT={{HOST_PGADMIN_PORT}}` to `env.docker`. Change the compose port lines to `"${PHP_FPM_HOST_SSH_PORT}:22"` and `"${PGADMIN_HOST_PORT}:80"`. After this fix every host-side port mapping uses Docker Compose runtime env-var syntax and can be tuned in `.env` without regenerating.

**What must change:**

1. **`templates/env.docker`:** Add `PHP_FPM_HOST_SSH_PORT={{HOST_SSH_PORT}}` (under `##### NGINX` block or a new `##### PHP-FPM` section) and `PGADMIN_HOST_PORT={{HOST_PGADMIN_PORT}}` (near the pgAdmin area or a new `##### PGADMIN` section).
2. **`templates/docker-compose.yml`:** `"{{HOST_SSH_PORT}}:22"` → `"${PHP_FPM_HOST_SSH_PORT}:22"`; `"{{HOST_PGADMIN_PORT}}:80"` → `"${PGADMIN_HOST_PORT}:80"`.
3. **`tests/unit/env_docker_template.bats`:** Token count rises from 4 to 6; add assertions for `PHP_FPM_HOST_SSH_PORT={{HOST_SSH_PORT}}` and `PGADMIN_HOST_PORT={{HOST_PGADMIN_PORT}}`.
4. **`tests/unit/top_level_templates.bats`:** Token count drops from 3 to 1 (only `{{NODE_SERVICE_BLOCK}}` remains); port-line test updated to assert `${PHP_FPM_HOST_SSH_PORT}:22` and `${PGADMIN_HOST_PORT}:80`; "renders to YAML" test removes now-absent `{{HOST_SSH_PORT}}` and `{{HOST_PGADMIN_PORT}}` sed substitutions and adds assertions the env-var strings survive; "no hardcoded ports" regex already covers `22|80|443` and will keep passing.
5. **`docs/functional-spec.md §6`:** `.env` fragment example adds `PHP_FPM_HOST_SSH_PORT` and `PGADMIN_HOST_PORT` lines.
6. **`docs/functional-spec.md §8.1`:** Port-mapping bullet updated — all four now use `${...}` env-var syntax.
7. **`docs/functional-spec.md §7`:** `{{HOST_SSH_PORT}}` and `{{HOST_PGADMIN_PORT}}` "Used in" updated to `env.docker` only.

**Task:** Add S13 / T037. No supersessions. T036 Done.

---

## Requirement reconciliation (revision 6)

| Requirement | Existing task IDs | Coverage or mismatch | New task IDs or blocker |
|---|---|---|---|
| php-fpm SSH port mapping resolves from `.env` at runtime | T011 (Done), T036 (Done — nginx ports) | **Mismatch.** `templates/docker-compose.yml` line 61 still uses `{{HOST_SSH_PORT}}` token baked at generation time. No `PHP_FPM_HOST_SSH_PORT` in `env.docker`. | T037 |
| pgAdmin port mapping resolves from `.env` at runtime | T011 (Done), T036 (Done — nginx ports) | **Mismatch.** `templates/docker-compose.yml` line 7 still uses `{{HOST_PGADMIN_PORT}}` token baked at generation time. No `PGADMIN_HOST_PORT` in `env.docker`. | T037 |
| All other requirements | T001–T036 | No mismatch identified. | — |

## Pending dispositions and questions

None. No supersessions.

## Approval

**Developer explicitly approved revision 6 on 2026-11-08** (add T037: fix SSH and pgAdmin port mappings to use `${PHP_FPM_HOST_SSH_PORT}` / `${PGADMIN_HOST_PORT}` Docker Compose env vars; update `env_docker_template.bats` and `top_level_templates.bats`; update functional-spec §6, §8.1, §7; no supersessions). The planner updated `docs/planning/tasks.md` to match the current `docs/tasks.md` (T036 status corrected to Done, T037 added). The functional-spec and technical-spec snapshots are unchanged (spec content changes happen during implementation). `Status: Approved` was set last.

---

## Proposal (revision 5, 2026-11-08)

Change planning against the approved revision 4 snapshots. Evidence: inspected `templates/docker-compose.yml` and `templates/env.docker`. The nginx service's port mappings use generator tokens that are baked in as literal integers at generation time (`"{{HOST_HTTPS_PORT}}:443"` → `"443:443"`), but `env.docker` exports `NGINX_HOST_HTTP_PORT` and `NGINX_HOST_HTTPS_PORT` to `.env` as Docker Compose runtime variables. Those two env vars are never consumed by `docker-compose.yml`, making them dead variables. Changing ports in `.env` post-generation has no effect on the actual port bindings. The SSH port (`{{HOST_SSH_PORT}}`) is also baked in but has no corresponding env var, which is the lesser issue.

The fix is to change the nginx service ports in the template to use `${NGINX_HOST_HTTP_PORT}` and `${NGINX_HOST_HTTPS_PORT}` (Docker Compose `${...}` env-var syntax), so they are resolved at runtime from `.env` rather than being hardcoded at generation time. The generator token (`{{HOST_HTTP_PORT}}` etc.) should no longer be used for the nginx ports row.

**What must change:**

1. **functional-spec §8.1:** The bullet "All host-side port mappings use template tokens…" is incorrect for the nginx HTTP/HTTPS ports. Update to say nginx HTTP/HTTPS port mappings use the Docker Compose `${NGINX_HOST_HTTP_PORT}` / `${NGINX_HOST_HTTPS_PORT}` env vars (populated from `.env`), so they can be changed in `.env` without regenerating. The pgAdmin and SSH ports remain token-driven (there are no corresponding env vars for those).

2. **functional-spec §7 token table:** Remove `{{HOST_HTTP_PORT}}` and `{{HOST_HTTPS_PORT}}` rows (they are no longer used in the template), OR retitle their "Used in" column to note they are only used in `env.docker` (which renders them into `.env`). They remain meaningful for `env.docker` token substitution; they are simply no longer in `docker-compose.yml`.

3. **technical-spec §8.1 (compose template description):** Update to match the new port mapping behaviour.

4. **`templates/docker-compose.yml`:** Change lines 52–53 from `"{{HOST_HTTPS_PORT}}:443"` / `"{{HOST_HTTP_PORT}}:80"` to `"${NGINX_HOST_HTTPS_PORT}:443"` / `"${NGINX_HOST_HTTP_PORT}:80"`.

5. **`tests/unit/top_level_templates.bats`:** The test "compose: all four host ports are token-driven" (line 24) checks for `{{HOST_HTTPS_PORT}}` and `{{HOST_HTTP_PORT}}` in port lines — this will need to be updated to check for `${NGINX_HOST_HTTP_PORT}` / `${NGINX_HOST_HTTPS_PORT}`. The test "compose: uses exactly the five tokens" (line 16) will need `{{HOST_HTTP_PORT}}` and `{{HOST_HTTPS_PORT}}` removed from the expected token list (down to three tokens). The test "compose: no obsolete top-level version key and no hardcoded host ports" (line 51–55) tests `grep -E '"[0-9]+:(22|80|443)"'` — this should still pass. The "renders to valid-looking YAML" test (line 58) performs manual token substitution: `{{HOST_HTTP_PORT}}` and `{{HOST_HTTPS_PORT}}` will no longer appear, so those `-e` sed expressions should be removed (they will just not match, but it is cleaner to remove them and add verification that `${NGINX_HOST_HTTP_PORT}` appears in the output instead).

**Task:** Add S13 / T036 to cover all five changes above under a single TDD cycle. The test is updated first to reflect the new expected template state (it will fail against the current template), then the template is fixed, then the spec sections are updated.

**No supersessions.** All existing tasks T001–T035 remain unchanged. T011 (top_level_templates.bats) is Done — T036 is a follow-up fix, not a rewrite of T011.

---

## Requirement reconciliation (revision 5)

| Requirement | Existing task IDs | Coverage or mismatch | New task IDs or blocker |
|---|---|---|---|
| nginx HTTP/HTTPS port mappings in `docker-compose.yml` resolve from `.env` at runtime (not baked in at generation time) | T011 (Done — template + test) | **Mismatch.** `templates/docker-compose.yml` lines 52–53 use `{{HOST_HTTP_PORT}}` / `{{HOST_HTTPS_PORT}}` tokens baked in at generation time. `env.docker` exports `NGINX_HOST_HTTP_PORT` / `NGINX_HOST_HTTPS_PORT`, which are never consumed by the generated compose file. The spec §8.1 describes the current (wrong) behaviour. `top_level_templates.bats` tests the current (wrong) template. | T036 |
| `{{HOST_HTTP_PORT}}` and `{{HOST_HTTPS_PORT}}` tokens remain valid for `env.docker` rendering | T011 (Done), T015 (env.docker, Done) | Still covered — these tokens appear in `templates/env.docker` and are tested by `tests/unit/env_docker_template.bats`. No change needed in those files. | — |
| All other requirements (SSH port, pgAdmin port, node block, nginx env vars, php-fpm, etc.) | T001–T035 | No mismatch identified. | — |

## Pending dispositions and questions

None. No supersessions. `docs/handoff.md` is stale (says no tasks are open); it needs a separate update after approval.

## Approval

**Developer explicitly approved revision 5 on 2026-11-08** (add T036: fix nginx port mappings to use `${NGINX_HOST_HTTP_PORT}`/`${NGINX_HOST_HTTPS_PORT}` Docker Compose env vars; update 3 tests in `top_level_templates.bats`; update functional-spec §8.1 and §7 and technical-spec §8.1; no supersessions). The planner updated `docs/planning/tasks.md` to match the current `docs/tasks.md` (T035 status corrected to Done, T036 added). The functional-spec and technical-spec snapshots are unchanged (spec content changes happen during implementation). `Status: Approved` was set last.

---

## Proposal (revision 4, 2026-11-07)

Change planning against the approved revision 3 snapshots. Evidence: `generate.sh` `main()` calls `append_gitignore "$OUT_DIR"` (line 535), which creates or extends a root `.gitignore` from `templates/gitignore.append`. `README.md` already documents it. A normal run writes 17 files. The specs said 16 and omitted it: functional-spec §3 tree and §6 table did not list it, and technical-spec §2, §16 and §20 (`minimal.bats`) did not mention it. The 17-count is already asserted by `main_e2e.bats` and by `minimal.bats` (changed in T034). There is no direct test of `append_gitignore` itself.

Decision: the code and README are right, so the specs are corrected to match. No code change is proposed.

Proposed changes:
1. **functional-spec §3:** add `templates/gitignore.append` to the repo tree.
2. **functional-spec §6:** add a `.gitignore` row (appended, idempotent, no header, no hand-edit check, never a `.new` file) and state that a normal run writes 17 files.
3. **functional-spec §12:** add `.gitignore` to the "must commit" table (the project's own file; the generator only appends).
4. **technical-spec §2:** add `append_gitignore()` to the function list.
5. **technical-spec §16:** add step 19 `append_gitignore OUT_DIR` (renumbering the print steps to 20 and 21) plus a short behavior note.
6. **technical-spec §20 (`minimal.bats`):** "all 16 output paths exist" becomes "all 17 (the 16 in functional-spec §6 plus the root `.gitignore`)".
7. **Add S12 / T035 (🔲 Todo):** a regression-only task with one new test file, `tests/unit/append_gitignore.bats`, giving direct coverage of `append_gitignore` (create, merge keeping existing lines, idempotent, no header). No `generate.sh` change is expected.

Historic task rows (T013 to T032, "15 output paths" and "16 output paths" wording in T025, T028 and T033) are left as written, as history. The specs are the source of truth.

## Earlier proposal (revision 3, 2026-11-07, approved)

Change planning against the approved revision 2 snapshots. Evidence: while starting T033 the implementer found that `/workspace/examples/` does not exist, and `git log --all -- examples` is empty, so the files were never committed. T016 is marked Done, yet its output is absent. Without them, 98 of 313 bats tests fail (215 pass), and T033's own test cannot pass. `tests/unit/examples.bats` already tests both files. The `external/dev-container-config/examples/*` files use a different schema (`schemaVersion` 2, devcontainer fields) and cannot be used.

Proposed changes (no spec changes; both specs already define the files in tech §18):
1. **Add S12 / T034 (🔲 Todo):** recreate `examples/minimal.answers.json` and `examples/full.answers.json` exactly as in technical-spec §18. Its one test is the existing `tests/unit/examples.bats`, which must pass unchanged. T016 stays Done and is not rewritten.
2. **T033 (⛔ Blocked, status was already set by the implementer):** add T034 to its **Depends on** line, and change the Blocked note to "waiting on T034". Description, test and AC are otherwise unchanged. Status cell changes are allowed after approval.

Order: T034 first, then T033.

## Earlier proposal (revision 2, 2026-11-07, approved)

Change planning against the previously approved snapshots in `docs/planning/`. The implementer's planning gate failed. `planning_task_scope` splits rows on every `|`, and the T001 AC contained an escaped pipe (`find . -type d \| sort`), giving 7 columns instead of 6. Proposed changes:

1. **T001 (Done, wording only):** the AC now reads "the sorted output of `find . -type d` matches functional-spec §3". The meaning is unchanged and the status stays `✅ Done · 2026-10-21`.
2. **technical-spec §4 (`--out-dir` row):** now states the directory is created with `mkdir -p` by `main()` right after `parse_args`. It also states the error text on failure, and that `--help` and argument errors do not create it. The earlier proposal called this "§3", but the flag table is in §4.
3. **T033:** spec references corrected to tech §4. The "update technical-spec §3" step is removed, because the planner already made that edit. Only the README is left for the implementer. Test, ID and scope are unchanged.

Original proposal (approved earlier): add **S12 / T033** to create `--out-dir` if missing, with the single test `tests/integration/out_dir.bats`.

Change planning. No approved baseline snapshots exist in `docs/planning/` (no reliable previous spec revision), so this reconciles only the requested change against tasks and code.

Proposed: add **S12 / T033** — create `--out-dir` if it does not exist (`mkdir -p` in `main()` right after `parse_args`), with a single integration test `tests/integration/out_dir.bats`, plus README and technical-spec §3 updates. All existing tasks (T001–T032) are unchanged.

## Requirement reconciliation

| Requirement | Existing task IDs | Coverage or mismatch | New task IDs or blocker |
|---|---|---|---|
| functional-spec §3 and §6, tech §2, §16 and §20: the output file set (rev 4) | T017 to T028 (generator), T029 (README, documents the `.gitignore` row), T032 (tests) | Mismatch. `generate.sh:535` calls `append_gitignore`, and README line 131 documents it, but both specs omit the root `.gitignore` and say 16. `main_e2e.bats` asserts 17, and `minimal.bats` was changed to 17 in T034. No direct test of `append_gitignore` exists. | Specs corrected (functional-spec §3, §6, §12; tech §2, §16, §20). T035 adds direct test coverage. |
| tech §18 and functional-spec §3: `examples/minimal.answers.json` and `examples/full.answers.json` exist | T016 (Done 2026-10-26), tests/unit/examples.bats | Mismatch (rev 3). T016 is marked Done but `/workspace/examples/` is absent and was never in git, so `examples.bats` and ~98 other tests fail. | T034 (restore), T033 now depends on it |
| Task table must parse as 6 columns (planning-core) | T001 | Mismatch: the escaped pipe in the T001 AC. Reworded, no pipe left. | T001 reworded in place, no new ID |
| `--out-dir` created if missing (tech §4 previously said only "Output directory"; now updated) | T026, T028, T032 | Mismatch. `/workspace/generate.sh` `parse_args` only stores `OUT_DIR`. `main()` calls `save_answers "$OUT_DIR"` before `commit_staged`, and nothing runs `mkdir -p` first, so a missing directory exits 1. The tests all use an existing temp dir, so there is no coverage. | T033 |

## Pending dispositions and questions

None. No supersessions. `docs/handoff.md` will be stale after approval: it says no tasks are open and lists the 16/17 mismatch as a follow-up. It needs a separate update to list T035 under Next.

## Approval

**Developer explicitly approved revision 4 on 2026-11-07** (specs corrected to 17 output files, T035 added; no supersessions). The developer then re-copied `docs/functional-spec.md`, `docs/technical-spec.md` and `docs/tasks.md` over the snapshots. The planner compared them with the sources by reading: functional-spec §3 tree, §6 `.gitignore` row and the 17-file sentence, §12 row and the last lines; technical-spec §2, §16 steps 19 to 21 and the behavior note, §20 `minimal.bats` line and the last lines; and the T035 row in tasks.md. All match. The planner role has no shell, so a full byte-level diff was not run. `Status: Approved` was set last.

Revision 3 history: **developer explicitly approved revision 3 on 2026-11-07** (add T034, T033 depends on T034; no supersessions). The developer then re-copied `docs/tasks.md` over `docs/planning/tasks.md` (the specs are unchanged). The planner compared the T001, T032, T033 and T034 rows and the end of the file by reading, and they match the source. The planner role has no shell, so a full byte-level diff was not run. `Status: Approved` was set last.

Revision 2 history: developer explicitly approved revision 2 on 2026-11-07 (T001 AC reworded, technical-spec §4 `--out-dir` row updated, T033 references corrected; no supersessions). The developer then re-copied `docs/tasks.md` and `docs/technical-spec.md` over the snapshots (functional-spec is unchanged). The planner compared them with the sources by reading: the T001 row, the T033 row, the technical-spec §4 `--out-dir` row, and the end of the technical-spec all match. The planner role has no shell, so a full byte-level diff was not run. `Status: Approved` was set last.
