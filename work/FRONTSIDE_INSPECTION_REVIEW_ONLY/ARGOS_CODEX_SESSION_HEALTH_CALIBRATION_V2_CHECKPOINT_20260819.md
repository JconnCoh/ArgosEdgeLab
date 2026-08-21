# Argos Codex session-health calibration V2 checkpoint

Date: 2026-08-19

Disposition: `APPROVED_BASELINE`

Scope: Codex task/session operational safety only. This checkpoint changes no
detector, threshold, image, wafer result, JBOD state, scheduled task, hold,
storage path, XML, training, or production-routing authority.

## Operator-approved policy

- Below 128 MiB: continue.
- At 128 MiB: confirm a text-only filesystem checkpoint and continue.
- At 256 MiB: run a deterministic continuity/authority health probe and
  continue only on PASS.
- At 384 MiB: run a second health probe and make a soft rotation
  recommendation; a passing task may finish safer in-place work.
- At 512 MiB: hard stop and resume from the filesystem checkpoint.
- At any size, an unexpected adjacent-measurement increase of 16 MiB or more
  is a provisional abnormal-growth hard alarm.
- The absolute prohibition on binary/media task payloads and both quarantined
  task IDs remains unchanged.

The staged sizes are calibration bands, not claims that text-only tasks fail at
those exact byte counts. Future changes require accumulated probe evidence and
operator approval.

## Exact rehearsal results

The updated metadata-only size guard returned:

- schema: `argos_codex_session_safety_check_v2`;
- state: `CHECKPOINT_ONLY_CONTINUE`;
- session: `01a0158f-629b-7712-81ad-e064603b68f1`;
- measured bytes: `148478519` (`141.600 MiB`);
- session content read: `false`.

The deterministic health probe then returned:

- schema: `argos_codex_session_health_probe_v1`;
- state: `PASS_ARGOS_CODEX_SESSION_HEALTH`;
- measured bytes: `148568747` (`141.686 MiB`);
- elapsed: `427 ms`;
- size band: `CHECKPOINT_ONLY_128_MIB`;
- project continuity: `PASS_ARGOS_PROJECT_CONTINUITY`;
- review-only: `true`;
- training/XML/production eligible: `false/false/false`;
- metadata-only session inspection: `true`;
- session content read: `false`.

Interaction-health attestation is not required until the 256 MiB band. At that
band and above, unresolved unexpected retries, repeated work, continuity
errors, or operator-reported degradation makes the probe fail.

## Rehearsal correction and prevention

The first probe rehearsal tried to dereference `.State` from the output of the
display-oriented continuity checker. Because that checker ends in
`Format-List`, the captured stream contained formatting records rather than a
raw result object. The rehearsal failed before becoming policy evidence. The
probe now requires successful checker completion, discards the rendered
formatting stream, and reads exact machine fields from the locked continuity
JSON. The failure signature, preflight, and recovery are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.

## Locked file hashes

- `AGENTS.md`:
  `F1A5774E7FCACA89B4749A2AB648BB566DC799AA58AF823083E94EDE5D3BE329`
- `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`:
  `019A04403A058CD8B7F68F38A7AC303E535BF546DD0EA7D749FC60A5C9C6C80C`
- `work/ARGOS_CODEX_SESSION_SAFETY.md`:
  `68BEB214CAAD941DDB0BC0C48359F110831BF24E4E4A631C7AA64E2A3497895F`
- `utilities/Confirm-ArgosCodexSessionSafety.ps1`:
  `3474408D888FAEBDCEBB0B25BA6337A30298D77BAFBD2BFD023263C3EE429E8F`
- `utilities/Confirm-ArgosCodexSessionHealth.ps1`:
  `57F6A61784B9983E10B2BAE3F8B7735428418B8DAD4EF935EA28ED69C9D74493`
- `utilities/Confirm-ArgosProjectContinuity.ps1`:
  `7E1F9D9B9325AA4BA6AF7DDB157795A806A6CBFE1FA0BA29176C5808CE6E62E4`
- `work/ACTIVE_ARGOS_EDGE_LAB_STATE.md`:
  `DF53199E6ABCFD12F27BEB61317D8E23145504F344C5B54CD313283620BD197E`
- `work/PROJECT_MEMORY_INDEX.md`:
  `F963E69E6C0809C7B86753C79BF4E069CEA7535F0B6FFA1AC2B92AC1D1949E8D`

## Preserved ordering and authority

Parent active checkpoint:
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/JBOD_D2S3_SIGNED_STATUS_COPY_IN_PROGRESS_AND_RECOVERY_CHECKPOINT_20260819.md`,
SHA-256
`605BA259A984E31A0E35FB3415B0F020E9168C956F63F52BBA4F150459E8E895`.

The signed D2S3 result remains nonterminal. D3, tray restart for C1D3A alone,
D: cutover, deletion, hold clearance, and C: recovery remain prohibited. The
migration scope remains bounded Argos inspection roots only, never the entire
C: drive. After the storage prerequisite is terminal and the controlled
cutover validations pass, return to PFC004 with six fiducial passes and preserve
the Slot07 notch hold. No judgment raster, alignment transfer, production
defect scoring, XML, training, or production authority is granted here.
