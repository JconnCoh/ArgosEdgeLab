# OCV-00 Deepest-Alias Inventory Contract

Disposition: `PENDING_GATE`

The OLS3 `F:` alias was temporary and correctly removed, but it was anchored
at `D:\KLARFExport`. That left the full lot-relative hierarchy beneath the
alias and caused 40 deeper children to cross the path budget. Returning only a
count made those identities unknowable from the signed result.

The corrected generic rule is:

1. Resolve and verify the exact requested subtree beneath the configured
   approved root.
2. Reject traversal, wildcard, missing-root, and reparse-ancestor conditions.
3. Create the temporary FileSystem PSDrive with its root equal to that exact
   requested subtree. The alias therefore starts at `F:\`, not
   `F:\PatternedFront\Lot_...`.
4. Perform every filesystem operation through the alias with provider-aware
   PowerShell cmdlets. Canonical configured-root-relative paths are provenance
   strings only and are never passed back to an I/O API.
5. Gate the exact alias path before use. If it is unsafe, record the child's
   exact bounded identity, both budget measurements, and an enumerated reason
   before skipping it.
   The 80-character component limit applies to newly created output names. An
   unchanged existing source component above 80 is recorded as provenance and
   is not reproduced in a new output name; it is not silently discarded for
   that reason alone.
6. Return `COMPLETE` only when there are no skip rows, access errors, reparse
   traversals, truncation, or depth-boundary directories.
7. Remove the alias in `finally` and prove removal after both success and
   injected failure.

The machine-readable companion freezes the required skip-row schema and the
Windows PowerShell 5.1 regression cases. No new JBOD request, source hashing,
image read, or image-processing work is authorized by this design record.
