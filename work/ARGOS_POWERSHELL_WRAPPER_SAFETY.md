# Argos PowerShell wrapper safety

Disposition: `APPROVED_BASELINE`.

This contract prevents the recurring Windows PowerShell wrapper failures that
previously appeared as a non-script value after `-File`, disabled-script
errors, string-to-Boolean conversion failures, collapsed arrays, quoting
errors, and the `Start-Process` duplicate `Path`/`PATH` failure.

## Mandatory entry-point contract

1. A portable entry point has one absolute scalar `.ps1` target.
2. A `.cmd` launcher resolves that target from quoted `%~dp0` and invokes:
   `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile
   -ExecutionPolicy Bypass -File "<absolute-script.ps1>"`.
3. Everything after `-File` is a script parameter. Expressions, arrays, and
   PowerShell literals never appear there.
4. Complex values are stored in a bounded UTF-8 JSON invocation manifest.
   JSON Booleans remain native `true`/`false`, arrays remain arrays, and paths
   remain individual string properties. Literal `$true`/`$false` strings and
   comma-serialized array arguments are prohibited.
5. The wrapper refuses missing script and manifest paths before launch. It
   does not forward `%*`, use `start`, use `Start-Process`, or invoke
   PowerShell with `-Command`.
6. Every operational target exposes a non-mutating `-Preflight` or
   `-Rehearsal` switch. Preflight validates paths, types, hashes, free space,
   overwrite refusal, and execution-context visibility before mutation.
7. Run `utilities/Confirm-ArgosPathBudget.ps1` on the complete planned path set
   and then run `utilities/Confirm-ArgosPowerShellWrapper.ps1` on the exact
   script, wrapper, and invocation manifest. Both checks must pass before the
   target preflight or rehearsal is executed under Windows PowerShell 5.1.
8. The static wrapper check never executes the target. A PASS proves the
   entry-point structure and manifest encoding only; the target's exact
   non-mutating preflight is still required.
9. Complex maintenance or inspection logic must not be serialized into an
   inline `-Command` string. Use a parsed `.ps1`. For a small read-only probe,
   capture `foreach`, `if`, or `try/finally` output in a variable, terminate
   the compound statement, and only then begin a separate pipeline.

The canonical non-mutating example is in `utilities/templates`:
`ARGOS_WRAPPER_TEMPLATE.cmd`, `ARGOS_WRAPPER_TEMPLATE.ps1`, and
`ARGOS_WRAPPER_TEMPLATE.invocation.json`. Copy and rename the short files,
keep the same entry-point shape, and replace only the target-specific manifest
schema and preflight checks.

Do not repair a wrapper error by changing detector thresholds, image inputs,
review authority, or operator feedback. First prove that no mutation occurred,
repair the entry point, repeat the static gate, and rerun the same bounded
non-mutating target preflight.
