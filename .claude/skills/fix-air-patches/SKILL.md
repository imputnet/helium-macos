---
name: fix-air-patches
description: Diagnose and fix failing Chromium patches in the Air browser repo. Use when `helium-chromium/utils/patches.py apply` (typically via `he` build commands) fails with errors like "patch file not found", "hunks failed", "saving rejects to ... .rej", or non-zero exit status from patch. Covers truncated patches, upstream drift (hunks that try to add code already present after Chromium/Brave updates), stray `.disabled` files, partial patch application, and updating the patch file so the fix persists.
---

# Fixing Air patches

Air patches live in `patches/` and are listed in `patches/series`. The applier is `helium-chromium/utils/patches.py`. Patches are applied to `build/src/` (the Chromium checkout) via `/usr/bin/patch -p1 --ignore-whitespace --forward`.

**The fix must live in both places:** the source tree under `build/src/` (so the current build can continue) *and* the `.patch` file under `patches/` (so the next clean checkout works). Patches must be committed and pushed — fixing only `build/src/` will be silently undone the next time someone runs the apply step.

## Failure modes and what they mean

| Symptom | Likely cause |
|---|---|
| `patch file '…/X.patch' not found` while `X.patch` exists on disk | The patch on disk is corrupt/truncated, or someone left `X.patch.disabled` next to it mid-edit. Check `git status patches/` and `git diff` the patch. |
| `N out of M hunks failed--saving rejects to …rej` | Upstream code (Chromium/Brave) changed under the patch. The hunk's context no longer matches, or the hunk tries to add code that's now already present. |
| Hunk adds methods/blocks that are already in the target file | Upstream drift — the new Chromium baseline already contains what the patch was adding. Trim the hunk to only the still-needed delta. |
| `malformed patch` / wrong line counts | The `@@ -a,b +c,d @@` header line counts no longer match the body (often after a manual edit). Recount. |

## Workflow

1. **Read the error carefully.** Note which patch, which file inside it, and how many hunks failed. The script aborts at the first failing patch, so anything earlier in `patches/series` already applied successfully.

2. **Inspect the rejects** at `build/src/<path>.rej`. The `.rej` file shows the exact hunks that failed — these are your diff to reconcile.

3. **Compare against the current target file** in `build/src/<path>`. For each failed hunk, check whether:
   - The added code is already present → remove that part from the hunk.
   - Context lines have shifted → recompute the `@@` header and/or expand context.
   - The target structure has changed shape → rewrite the hunk against the new shape.

4. **Check `git status patches/`** before editing. A `.patch.disabled` sibling or an unexpected `M` on the patch file usually means someone left work in progress. Decide whether to `git checkout` the patch and rebuild from there, or keep the local edits.

5. **Edit the patch file** under `patches/helium/...` (or wherever it lives in `patches/series`). When trimming a hunk, you MUST update the `@@ -orig_start,orig_len +new_start,new_len @@` header to match the new line counts. Blank context lines need a single leading space (`" "`) — `--ignore-whitespace` is forgiving but it's safer to keep the format strict.

6. **Reconcile `build/src/`** so the in-progress build can continue without restarting from scratch. Either:
   - Manually apply the corrected diff to the target file in `build/src/`, then delete the `.rej` file, OR
   - Reverse the failing patch (`patch -R -p1 -i <patch>` from `build/src/`) and then re-run the apply script. Reversing is cleaner if many hunks need rework.

7. **Dry-run verify** before continuing the build:
   ```bash
   cd /Users/franz.muehringer/Projects/chrome-air/air/build/src
   /usr/bin/patch -p1 --ignore-whitespace --dry-run --forward \
     -i /Users/franz.muehringer/Projects/chrome-air/air/patches/helium/core/<patch>.patch
   ```
   "Ignoring previously applied" for every hunk = the patch matches `build/src/` and will apply cleanly on a fresh checkout.

8. **Resume the build.** Per project memory: dev commands need `venv` activated and go through `./dev.sh`. Re-run the same `he`/build command that failed. The apply step will replay earlier patches as `--forward` (no-op for already-applied) and hit the fixed patch.

9. **Commit and push.** This repo's whole point is the patch set — leaving the fix uncommitted means it ships only on the developer's machine. Commit only the patch file under `patches/`, **not** the modified files under `build/src/` (that directory is the Chromium checkout, not part of this repo).

## Common cleanup

- `*.patch~` files are vim/editor backups — safe to delete if not wanted.
- `*.patch.disabled` files are usually mid-edit detritus. Confirm with the user before deleting; they may represent intentional "park this patch" state.
- `*.rej` files in `build/src/` should be deleted once the rejects are reconciled, otherwise they'll confuse future patch runs.

## What NOT to do

- Don't `--no-verify` past hooks or `--force` past patch errors. Failed hunks mean the resulting source tree is inconsistent — pushing through compiles into broken binaries.
- Don't edit only `build/src/` and call it fixed. That directory is not the repo; the patch must carry the fix forward.
- Don't blindly regenerate patches with `quilt refresh` or similar without reading the diff — you can accidentally widen the patch to capture unrelated drift in the surrounding code, which makes future maintenance worse.
- Don't delete or disable a patch to "make the build green" without understanding what feature it carries. The series file order matters and patches often depend on earlier ones.
