# Planning review

Status: Approved

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
