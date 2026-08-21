# Argos Windows path-length safety contract

Date: 2026-08-14

State: `APPROVED_BASELINE`

## Rule

Path length is a planning input, not a runtime discovery. Before creating any
new output root, extracting an archive, or launching Windows PowerShell 5.1 or
.NET Framework work, enumerate the planned source paths and the longest
possible output filenames and run:

`utilities/Confirm-ArgosPathBudget.ps1`

The preflight reads path metadata only. It does not open image or session
content.

When a prior tree will be copied, rebase every source child under the planned
destination and apply all intended short-name mappings before the path check.
Checking only newly generated files does not cover inherited legacy names.

## Budgets

- Reserve 32 characters for `.partial`, atomic-replace, GUID, retry, and
  extraction suffixes.
- Effective length below 200 characters passes.
- Effective length of 200 through 229 requires a verified short alias or short
  staging root before the first write or process launch.
- Effective length of 230 or greater is a hard stop.
- A single path component longer than 80 characters is a hard stop for new
  outputs.

These limits deliberately leave headroom below the legacy Windows `MAX_PATH`
boundary. Existing historical paths are preserved; the rule applies to every
new run and retry.

## Naming contract

- Put the timestamp once, in the run-root name.
- Keep the run-root identifier at 48 characters or fewer when practical.
- Do not repeat the inspection family, revision, timestamp, tile ID, and class
  prose at every directory level.
- Use short stable artifact codes in filenames and store the full class,
  disposition, and explanation in the manifest.
- Keep tile directories to the canonical tile ID only.
- Never solve a path problem by renaming original evidence or changing its
  identity. Use an alias to the same bytes or a checksummed short staging copy.

## Short-path recovery before launch

For work within the unchanged project tree, prefer a verified `subst` alias
such as `R:\` to the workspace root. Before use:

1. verify the drive letter is unused or already maps to the exact workspace;
2. create the alias before creating the output root;
3. hash a small sentinel through both paths to prove byte identity;
4. run the path-budget check again using the short form;
5. create and consume the alias in the same execution context as the work;
6. record the full root, alias root, hashes, and `imageContentChanged=false` in
   the run manifest.

If a child, scheduled task, service, or elevated process cannot see the alias,
create and verify it inside that exact context or use a short physical staging
root with byte-for-byte source hashes. Do not launch first and wait for a path
error.

## Evidence from the D5 recovery

The D5 reviewer already contains 202-character paths. Its structural-routing
analysis contains 247-character paths before any temporary suffix is added.
Those artifacts remain historical evidence and are not renamed. They show why
future run roots must be shorter before execution.
